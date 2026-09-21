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
    /// Whether the event tap is currently installed and enabled.
    private(set) var isActive = false

    var launchAtLoginState: LaunchAtLoginManager.State {
        launchAtLogin.state
    }

    var launchAtLoginError: String? {
        launchAtLogin.error
    }

    var launchesAtLogin: Bool {
        launchAtLogin.isEnabled
    }

    var launchAtLoginDetail: String? {
        launchAtLogin.detail
    }

    var requiresLaunchAtLoginApproval: Bool {
        launchAtLogin.requiresApproval
    }

    var needsLaunchAtLoginRepair: Bool {
        launchAtLogin.needsRepair
    }

    private let remapper = KeyRemapper()
    private let launchAtLogin = LaunchAtLoginManager()
    private var supervisor: Task<Void, Never>?
    private var didPrompt = false

    private let inactiveInterval: Duration = .seconds(1)
    private let activeInterval: Duration = .seconds(5)

    func start() {
        launchAtLogin.configureOnLaunch()
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
            if !remapper.isActive {
                remapper.start()
            }
        } else if remapper.isActive {
            remapper.stop()
        }
        isActive = remapper.isActive
        launchAtLogin.refreshStatusIfStale()
    }

    // MARK: - Permissions

    /// Shows the system Accessibility prompt once per launch.
    private func requestAccessibilityPromptOnce() {
        guard !didPrompt else { return }
        didPrompt = true
        // Use a string literal key because the CoreServices global
        // `kAXTrustedCheckOptionPrompt` is not marked `@Sendable` in Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Actions

    func setLaunchesAtLogin(_ enabled: Bool) {
        launchAtLogin.setEnabled(enabled)
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func openLoginItemsSettings() {
        launchAtLogin.openSettings()
    }

    func restart() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            NSLog("Command Input: Failed to launch restart process: \(error.localizedDescription)")
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
