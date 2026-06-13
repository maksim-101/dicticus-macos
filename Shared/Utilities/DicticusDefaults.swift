import Foundation

/// Platform-conditional UserDefaults suite.
/// macOS: .standard (app-local, no group entitlement needed).
/// iOS: group.com.dicticus suite (Shortcuts IPC + keyboard extension).
public enum DicticusDefaults {
    public static var suite: UserDefaults {
#if os(macOS)
        return .standard
#else
        return UserDefaults(suiteName: "group.com.dicticus") ?? .standard
#endif
    }
}
