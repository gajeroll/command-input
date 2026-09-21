import SwiftUI

@main
struct CommandInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model)
        } label: {
            StatusLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Bridges app lifecycle events that are still clearer through NSApplicationDelegate.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}

private struct StatusLabel: View {
    let model: AppModel

    var body: some View {
        Image(systemName: model.isActive ? "command" : "exclamationmark.triangle.fill")
            .accessibilityLabel(
                model.isActive ? "Command Input: Active" : "Command Input: Accessibility Permission Required"
            )
    }
}

private struct MenuContent: View {
    let model: AppModel

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        Text("Command Input \(version)")
        Text(model.isActive ? "Status: Active" : "Status: Accessibility Permission Required")

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { model.launchesAtLogin },
            set: { model.setLaunchesAtLogin($0) }
        ))

        if let detail = model.launchAtLoginDetail {
            Text(detail)
        }
        if let error = model.launchAtLoginError {
            Text("Launch at Login Error: \(error)")
        }

        if model.requiresLaunchAtLoginApproval {
            Button("Open Login Items Settings") {
                model.openLoginItemsSettings()
            }
        } else if model.needsLaunchAtLoginRepair {
            Button("Repair Launch at Login") {
                model.setLaunchesAtLogin(true)
            }
        }

        Divider()

        if !model.isActive {
            Button("Open Accessibility Settings") {
                model.openAccessibilitySettings()
            }
        }
        Button("Restart") {
            model.restart()
        }

        Divider()

        Button("Quit") {
            model.quit()
        }
        .keyboardShortcut("q")
    }
}
