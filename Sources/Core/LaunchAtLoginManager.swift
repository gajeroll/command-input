import Foundation
import Observation
import ServiceManagement

/// Owns launch-at-login preference, SMAppService registration, and repair.
@MainActor
@Observable
public final class LaunchAtLoginManager {
    public enum State {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound
    }

    public private(set) var state: State = .notRegistered
    public private(set) var error: String?

    public var isEnabled: Bool {
        switch state {
        case .enabled, .requiresApproval: true
        case .notRegistered, .notFound: false
        }
    }

    public var detail: String? {
        if requiresApproval {
            return "Approve Command Input in Login Items to finish setup."
        }
        if needsRepair {
            return "macOS is not honoring the Launch at Login setting."
        }
        return nil
    }

    public var requiresApproval: Bool {
        state == .requiresApproval
    }

    public var needsRepair: Bool {
        guard storedPreference == true else { return false }

        switch state {
        case .notRegistered, .notFound: return true
        case .enabled, .requiresApproval: return false
        }
    }

    private let service: any LoginItemService
    private let defaults: UserDefaults
    private let identity: () -> String
    private var lastRefresh: ContinuousClock.Instant?

    private let refreshInterval: Duration = .seconds(15)
    private let maximumRepairAttempts = 3

    public init(
        service: any LoginItemService = SystemLoginItemService(),
        defaults: UserDefaults = .standard,
        identity: @escaping () -> String = { LaunchAtLoginManager.bundleIdentity() }
    ) {
        self.service = service
        self.defaults = defaults
        self.identity = identity
    }

    public func configureOnLaunch() {
        refreshStatus()
        migrateLegacyPreferenceIfNeeded()

        guard let wantsLaunchAtLogin = storedPreference else {
            enableOnFirstInstalledRun()
            return
        }
        guard wantsLaunchAtLogin else { return }

        switch state {
        case .enabled, .requiresApproval:
            clearRepairBudget()
        case .notRegistered, .notFound:
            repairRegistrationWithinBudget()
        }
    }

    public func refreshStatus() {
        lastRefresh = .now

        switch service.status {
        case .enabled:
            state = .enabled
            error = nil
        case .requiresApproval:
            state = .requiresApproval
        case .notFound:
            state = .notFound
        case .notRegistered:
            state = .notRegistered
        @unknown default:
            state = .notRegistered
        }
    }

    public func refreshStatusIfStale() {
        if let last = lastRefresh, ContinuousClock.now - last < refreshInterval {
            return
        }
        refreshStatus()
    }

    public func setEnabled(_ enabled: Bool) {
        refreshStatus()
        storePreference(enabled)
        clearRepairBudget()

        if enabled {
            register()
        } else {
            unregister()
        }
    }

    public func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func enableOnFirstInstalledRun() {
        guard isInstalledInApplicationsDirectory else { return }
        setEnabled(true)
    }

    private func migrateLegacyPreferenceIfNeeded() {
        guard storedPreference == nil,
              defaults.object(forKey: DefaultsKey.legacyDidConfigureLaunchAtLogin) != nil
        else {
            return
        }

        switch state {
        case .enabled, .requiresApproval, .notFound:
            storePreference(true)
        case .notRegistered:
            storePreference(false)
        }
    }

    private func register() {
        switch state {
        case .enabled, .requiresApproval:
            error = nil
            return
        case .notRegistered, .notFound:
            break
        }

        if state == .notFound {
            try? service.unregister()
        }

        do {
            try service.register()
            refreshStatus()

            switch state {
            case .enabled, .requiresApproval:
                error = nil
            case .notRegistered, .notFound:
                error = "macOS did not keep the login item registration."
            }
        } catch {
            refreshStatus()
            recordError(error)
        }
    }

    private func unregister() {
        switch state {
        case .enabled, .requiresApproval:
            do {
                try service.unregister()
                refreshStatus()
                error = nil
            } catch {
                refreshStatus()
                recordError(error)
            }
        case .notRegistered, .notFound:
            error = nil
        }
    }

    private func repairRegistrationWithinBudget() {
        let currentIdentity = identity()
        if defaults.string(forKey: DefaultsKey.repairBudget) != currentIdentity {
            defaults.set(currentIdentity, forKey: DefaultsKey.repairBudget)
            defaults.set(0, forKey: DefaultsKey.repairAttempts)
        }

        let attempts = defaults.integer(forKey: DefaultsKey.repairAttempts)
        guard attempts < maximumRepairAttempts else { return }
        defaults.set(attempts + 1, forKey: DefaultsKey.repairAttempts)

        register()
    }

    private func clearRepairBudget() {
        defaults.removeObject(forKey: DefaultsKey.repairAttempts)
        defaults.removeObject(forKey: DefaultsKey.repairBudget)
    }

    private var storedPreference: Bool? {
        defaults.object(forKey: DefaultsKey.launchAtLoginPreference) as? Bool
    }

    private func storePreference(_ enabled: Bool) {
        defaults.set(enabled, forKey: DefaultsKey.launchAtLoginPreference)
        defaults.removeObject(forKey: DefaultsKey.legacyDidConfigureLaunchAtLogin)
    }

    private func recordError(_ error: Error) {
        self.error = error.localizedDescription
        NSLog("Failed to update launch-at-login: \(error.localizedDescription)")
    }

    nonisolated public static func bundleIdentity() -> String {
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
}
