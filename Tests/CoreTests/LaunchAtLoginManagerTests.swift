import Foundation
import ServiceManagement
import Testing
@testable import CommandInputCore

@MainActor
final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registerImpl: () throws -> Void = {}
    var unregisterImpl: () throws -> Void = {}
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register() throws {
        registerCount += 1
        try registerImpl()
    }

    func unregister() throws {
        unregisterCount += 1
        try unregisterImpl()
    }
}

private struct FakeError: Error, LocalizedError {
    var errorDescription: String? { "registration failed" }
}

@Suite("LaunchAtLoginManager")
@MainActor
struct LaunchAtLoginManagerTests {
    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "test.commandinput.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            defaults.synchronize()
            let plist = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Preferences/\(suite).plist")
            try? FileManager.default.removeItem(at: plist)
        }
        body(defaults)
    }

    @Test("legacy enabled or lost records become an opt-in")
    func migrateLegacyOptIn() {
        withIsolatedDefaults { defaults in
            defaults.set(true, forKey: DefaultsKey.legacyDidConfigureLaunchAtLogin)
            let service = FakeLoginItemService()
            service.status = .notFound
            let manager = LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" })

            manager.configureOnLaunch()

            #expect(defaults.object(forKey: DefaultsKey.launchAtLoginPreference) as? Bool == true)
            #expect(service.unregisterCount == 1)
            #expect(service.registerCount == 1)
        }
    }

    @Test("legacy unregistered records become an opt-out")
    func migrateLegacyOptOut() {
        withIsolatedDefaults { defaults in
            defaults.set(true, forKey: DefaultsKey.legacyDidConfigureLaunchAtLogin)
            let service = FakeLoginItemService()
            service.status = .notRegistered
            let manager = LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" })

            manager.configureOnLaunch()

            #expect(defaults.object(forKey: DefaultsKey.launchAtLoginPreference) as? Bool == false)
            #expect(service.registerCount == 0)
            #expect(manager.needsRepair == false)
        }
    }

    @Test("repair stops after three attempts on the same identity")
    func repairBudgetExhausts() {
        withIsolatedDefaults { defaults in
            defaults.set(true, forKey: DefaultsKey.launchAtLoginPreference)
            let service = FakeLoginItemService()
            service.status = .notRegistered

            for _ in 0..<5 {
                let manager = LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" })
                manager.configureOnLaunch()
            }

            #expect(service.registerCount == 3)
            #expect(defaults.integer(forKey: DefaultsKey.repairAttempts) == 3)
        }
    }

    @Test("a new identity resets the repair budget")
    func repairBudgetResetsOnIdentityChange() {
        withIsolatedDefaults { defaults in
            defaults.set(true, forKey: DefaultsKey.launchAtLoginPreference)
            let service = FakeLoginItemService()
            service.status = .notRegistered

            LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" }).configureOnLaunch()
            LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" }).configureOnLaunch()
            LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" }).configureOnLaunch()
            #expect(service.registerCount == 3)

            LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-2" }).configureOnLaunch()
            #expect(service.registerCount == 4)
        }
    }

    @Test("notFound unregisters before registering")
    func notFoundUnregistersFirst() {
        withIsolatedDefaults { defaults in
            defaults.set(true, forKey: DefaultsKey.launchAtLoginPreference)
            let service = FakeLoginItemService()
            service.status = .notFound
            let manager = LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" })

            manager.setEnabled(true)

            #expect(service.unregisterCount == 1)
            #expect(service.registerCount == 1)
        }
    }

    @Test("a failed register records the error")
    func registerFailureRecordsError() {
        withIsolatedDefaults { defaults in
            let service = FakeLoginItemService()
            service.status = .notRegistered
            service.registerImpl = { throw FakeError() }
            let manager = LaunchAtLoginManager(service: service, defaults: defaults, identity: { "id-1" })

            manager.setEnabled(true)

            #expect(manager.error == "registration failed")
        }
    }
}
