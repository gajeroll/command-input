/// UserDefaults keys used by Command Input. The raw strings are part of the
/// on-disk format and must not change.
public enum DefaultsKey {
    public static let launchAtLoginPreference = "launchAtLoginEnabled"
    public static let legacyDidConfigureLaunchAtLogin = "didConfigureLaunchAtLogin"
    public static let repairAttempts = "launchAtLoginRepairAttempts"
    public static let repairBudget = "launchAtLoginRepairBudget"
}
