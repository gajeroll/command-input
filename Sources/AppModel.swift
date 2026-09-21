import Cocoa
import Observation
import ServiceManagement

/// Owns app state, permission polling, and user actions.
///
/// The event tap is activated automatically after Accessibility permission is granted.
/// Polling slows down once the app is active.
@MainActor
@Observable
final class AppModel {
    /// What macOS currently reports for the main app login item.
    enum LaunchAtLoginState {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound
    }

    /// Whether the event tap is currently installed and enabled.
    private(set) var isActive = false

    private(set) var launchAtLoginState: LaunchAtLoginState = .notRegistered

    /// The last registration failure, kept until a later attempt succeeds.
    private(set) var launchAtLoginError: String?

    /// True while macOS holds a registration, including one awaiting approval,
    /// so turning the toggle off can always undo it.
    var launchesAtLogin: Bool {
        switch launchAtLoginState {
        case .enabled, .requiresApproval: true
        case .notRegistered, .notFound: false
        }
    }

    /// Extra explanation shown only when the registration needs attention.
    var launchAtLoginDetail: String? {
        if requiresLaunchAtLoginApproval {
            return "Approve Command Input in Login Items to finish setup."
        }
        if needsLaunchAtLoginRepair {
            return "macOS is not honoring the Launch at Login setting."
        }
        return nil
    }

    var requiresLaunchAtLoginApproval: Bool {
        launchAtLoginState == .requiresApproval
    }

    /// True while the stored preference asks for launch at login but macOS is not
    /// honoring it, which is the only situation repairing the registration helps.
    var needsLaunchAtLoginRepair: Bool {
        guard storedPreference == true else { return false }

        switch launchAtLoginState {
        case .notRegistered, .notFound: return true
        case .enabled, .requiresApproval: return false
        }
    }

    private let remapper = KeyRemapper()
    private let defaults = UserDefaults.standard
    private var supervisor: Task<Void, Never>?
    private var didPrompt = false
    private var lastLaunchAtLoginRefresh: ContinuousClock.Instant?

    private let inactiveInterval: Duration = .seconds(1)
    private let activeInterval: Duration = .seconds(5)

    /// Querying ServiceManagement crosses an XPC boundary, so it runs far less
    /// often than the permission check while still following System Settings.
    private let launchAtLoginRefreshInterval: Duration = .seconds(15)

    private let launchAtLoginPreferenceKey = "launchAtLoginEnabled"
    private let legacyDidConfigureLaunchAtLoginKey = "didConfigureLaunchAtLogin"
    private let repairAttemptsKey = "launchAtLoginRepairAttempts"
    private let repairBudgetKey = "launchAtLoginRepairBudget"
    private let maximumRepairAttempts = 3

    func start() {
        configureLaunchAtLogin()
        requestAccessibilityPromptOnce()
        guard supervisor == nil else { return }

        supervisor = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                let interval = self.isActive ? self.activeInterval : self.inactiveInterval
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        supervisor?.cancel()
        supervisor = nil
        remapper.stop()
    }

    /// Checks permission and starts the event tap as soon as macOS allows it.
    private func tick() {
        if AXIsProcessTrusted() {
            remapper.start()
        }
        isActive = remapper.isActive
        refreshLaunchAtLoginStatusIfStale()
    }

    // MARK: - Permissions

    /// Shows the system Accessibility prompt once per launch.
    private func requestAccessibilityPromptOnce() {
        guard !didPrompt else { return }
        didPrompt = true
        // Use the stable string key because the CoreServices global is not
        // concurrency-safe in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Launch at Login

    /// Applies the stored preference and repairs a registration macOS no longer honors.
    ///
    /// The stored preference is the source of truth. `SMAppService.status` only
    /// describes what macOS currently believes, and that is exactly what drifts
    /// when a registration breaks, so it cannot stand in for the user's choice.
    private func configureLaunchAtLogin() {
        refreshLaunchAtLoginStatus()
        migrateLegacyPreferenceIfNeeded()

        guard let wantsLaunchAtLogin = storedPreference else {
            enableOnFirstInstalledRun()
            return
        }
        guard wantsLaunchAtLogin else { return }

        switch launchAtLoginState {
        case .enabled, .requiresApproval:
            clearRepairBudget()
        case .notRegistered, .notFound:
            repairRegistrationWithinBudget()
        }
    }

    /// Opts a new installation in, but never a build directory copy, so a bundle
    /// that is about to move or be rebuilt is not recorded as the login item.
    private func enableOnFirstInstalledRun() {
        guard isInstalledInApplicationsDirectory else { return }
        setLaunchesAtLogin(true)
    }

    /// Derives a preference for installations that predate one being stored.
    ///
    /// The previous build recorded setup before registration completed, so a
    /// missing record cannot be told apart from an opt-out. A lost record is
    /// treated as broken, while an unregistered one stays off rather than
    /// overriding a choice the user may have made in System Settings.
    private func migrateLegacyPreferenceIfNeeded() {
        guard storedPreference == nil,
              defaults.object(forKey: legacyDidConfigureLaunchAtLoginKey) != nil
        else {
            return
        }

        switch launchAtLoginState {
        case .enabled, .requiresApproval, .notFound:
            storePreference(true)
        case .notRegistered:
            storePreference(false)
        }
    }

    func refreshLaunchAtLoginStatus() {
        lastLaunchAtLoginRefresh = .now

        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginState = .enabled
            // Clearing here is safe because every failure path records its error
            // after refreshing, so an error can never wipe itself.
            launchAtLoginError = nil
        case .requiresApproval:
            launchAtLoginState = .requiresApproval
        case .notFound:
            launchAtLoginState = .notFound
        case .notRegistered:
            launchAtLoginState = .notRegistered
        @unknown default:
            // Keep an unrecognized state out of the repair path.
            launchAtLoginState = .notRegistered
        }
    }

    private func refreshLaunchAtLoginStatusIfStale() {
        if let last = lastLaunchAtLoginRefresh,
           ContinuousClock.now - last < launchAtLoginRefreshInterval {
            return
        }
        refreshLaunchAtLoginStatus()
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        // The cached state is up to 15 seconds old, which is long enough to register
        // over an existing item or unregister a missing one. One query per explicit
        // user action is cheap.
        refreshLaunchAtLoginStatus()
        storePreference(enabled)
        clearRepairBudget()

        if enabled {
            register()
        } else {
            unregister()
        }
    }

    private func register() {
        switch launchAtLoginState {
        case .enabled, .requiresApproval:
            launchAtLoginError = nil
            return
        case .notRegistered, .notFound:
            break
        }

        // A lost record is not replaced by registering over it, so drop the stale
        // entry first. It is already unreachable, so a failure here is expected.
        if launchAtLoginState == .notFound {
            try? SMAppService.mainApp.unregister()
        }

        do {
            try SMAppService.mainApp.register()
            refreshLaunchAtLoginStatus()

            switch launchAtLoginState {
            case .enabled, .requiresApproval:
                launchAtLoginError = nil
            case .notRegistered, .notFound:
                launchAtLoginError = "macOS did not keep the login item registration."
            }
        } catch {
            refreshLaunchAtLoginStatus()
            recordError(error)
        }
    }

    private func unregister() {
        switch launchAtLoginState {
        case .enabled, .requiresApproval:
            do {
                try SMAppService.mainApp.unregister()
                refreshLaunchAtLoginStatus()
                launchAtLoginError = nil
            } catch {
                refreshLaunchAtLoginStatus()
                recordError(error)
            }
        case .notRegistered, .notFound:
            launchAtLoginError = nil
        }
    }

    /// Re-registers a preference macOS dropped, a bounded number of times.
    ///
    /// The budget is tied to the installed bundle so reinstalling or updating
    /// starts over, while an installation macOS keeps rejecting stops retrying on
    /// every launch and waits for the user to repair it from the menu.
    private func repairRegistrationWithinBudget() {
        if defaults.string(forKey: repairBudgetKey) != installationIdentity {
            defaults.set(installationIdentity, forKey: repairBudgetKey)
            defaults.set(0, forKey: repairAttemptsKey)
        }

        let attempts = defaults.integer(forKey: repairAttemptsKey)
        guard attempts < maximumRepairAttempts else { return }
        defaults.set(attempts + 1, forKey: repairAttemptsKey)

        register()
    }

    private func clearRepairBudget() {
        defaults.removeObject(forKey: repairAttemptsKey)
        defaults.removeObject(forKey: repairBudgetKey)
    }

    private var storedPreference: Bool? {
        defaults.object(forKey: launchAtLoginPreferenceKey) as? Bool
    }

    private func storePreference(_ enabled: Bool) {
        defaults.set(enabled, forKey: launchAtLoginPreferenceKey)
        defaults.removeObject(forKey: legacyDidConfigureLaunchAtLoginKey)
    }

    private func recordError(_ error: Error) {
        launchAtLoginError = error.localizedDescription
        NSLog("Failed to update launch-at-login: \(error.localizedDescription)")
    }

    /// Identifies this copy of the app, so replacing it grants a fresh repair budget.
    ///
    /// The executable timestamp stands in for a build number because `CFBundleVersion`
    /// is fixed in `Info.plist` and does not change when the app is rebuilt.
    private var installationIdentity: String {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let built = Bundle.main.executableURL
            .flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]) }
            .flatMap(\.contentModificationDate)

        return "\(path)#\(built?.timeIntervalSince1970 ?? 0)"
    }

    private var isInstalledInApplicationsDirectory: Bool {
        let bundlePath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true),
        ]

        return directories.contains { directory in
            bundlePath.hasPrefix("\(directory.resolvingSymlinksInPath().path)/")
        }
    }

    // MARK: - Actions

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func restart() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
