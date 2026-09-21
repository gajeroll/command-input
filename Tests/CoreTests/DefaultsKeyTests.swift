import Testing
@testable import CommandInputCore

@Suite("DefaultsKey")
struct DefaultsKeyTests {
    @Test("on-disk key names stay stable")
    func rawValues() {
        #expect(DefaultsKey.launchAtLoginPreference == "launchAtLoginEnabled")
        #expect(DefaultsKey.legacyDidConfigureLaunchAtLogin == "didConfigureLaunchAtLogin")
        #expect(DefaultsKey.repairAttempts == "launchAtLoginRepairAttempts")
        #expect(DefaultsKey.repairBudget == "launchAtLoginRepairBudget")
    }
}
