import Cocoa
import Observation

/// Owns app state, permission polling, and user actions.
///
/// The event tap is activated automatically after Accessibility permission is granted.
/// Polling slows down once the app is active.
@MainActor
@Observable
final class AppModel {
    /// Whether the event tap is currently installed and enabled.
    private(set) var isActive = false

    private let remapper = KeyRemapper()
    private var supervisor: Task<Void, Never>?
    private var didPrompt = false

    private let inactiveInterval: Duration = .seconds(1)
    private let activeInterval: Duration = .seconds(5)

    func start() {
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

    // MARK: - Actions

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
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
