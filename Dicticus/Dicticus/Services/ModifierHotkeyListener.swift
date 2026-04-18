import CoreGraphics
import Foundation

/// CGEventTap-based listener for modifier-only hotkeys (Fn+Shift, Fn+Control, Fn+Option).
///
/// Runs in parallel with KeyboardShortcuts, which cannot capture modifier-only combos.
/// Per D-08: parallel system architecture.
/// Per D-09: Fn+Shift = plain dictation default, Fn+Control = AI cleanup default.
///
/// Security: Uses `.listenOnly` option — never intercepts or modifies events.
/// Only listens for `.flagsChanged` events — never sees keystrokes (T-05-01).
/// Requires Accessibility permission; silently does not start if missing (T-05-02).
/// Callback performs O(1) flag comparison only — no blocking (T-05-03).
///
/// NOT @MainActor: runs on a dedicated background CFRunLoop thread.
/// Communication back to HotkeyManager happens via closures dispatched to MainActor.
///
/// @unchecked Sendable: thread safety is managed manually.
/// - `previousFlags` is accessed only from the single CGEventTap callback thread.
/// - `onComboActivated`/`onComboReleased` closures are set before `start()` and called
///   only via DispatchQueue.main.async, ensuring they always run on the main thread.
/// - Combo config reads hit UserDefaults (which is internally thread-safe).
class ModifierHotkeyListener: @unchecked Sendable {

    // MARK: - Configuration

    /// The modifier combo mapped to plain dictation mode.
    /// Default: .fnShift per D-09. Persisted in UserDefaults.
    var plainDictationCombo: ModifierCombo {
        get {
            if let raw = UserDefaults.standard.string(forKey: "modifierPlainDictation"),
               let combo = ModifierCombo.allCases.first(where: { "\($0)" == raw }) {
                return combo
            }
            return .fnShift
        }
        set {
            UserDefaults.standard.set("\(newValue)", forKey: "modifierPlainDictation")
        }
    }

    /// The modifier combo mapped to AI cleanup mode.
    /// Default: .fnControl per D-09. Persisted in UserDefaults.
    var cleanupCombo: ModifierCombo {
        get {
            if let raw = UserDefaults.standard.string(forKey: "modifierAiCleanup"),
               let combo = ModifierCombo.allCases.first(where: { "\($0)" == raw }) {
                return combo
            }
            return .fnControl
        }
        set {
            UserDefaults.standard.set("\(newValue)", forKey: "modifierAiCleanup")
        }
    }

    // MARK: - Closures for HotkeyManager wiring

    /// Called when a modifier combo is fully pressed. Set by HotkeyManager in Plan 02.
    var onComboActivated: ((DictationMode) -> Void)?

    /// Called when a modifier combo is released. Set by HotkeyManager in Plan 02.
    var onComboReleased: ((DictationMode) -> Void)?

    // MARK: - Private state

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?

    /// Previous CGEventFlags state — updated in callback to detect transitions.
    /// Accessed only from the callback thread (the dedicated background RunLoop).
    private var previousFlags: CGEventFlags = []

    // MARK: - C-compatible callback

    /// Static C-compatible callback for CGEventTap.
    ///
    /// Must be static (not a closure or instance method) — CGEventTapCallBack is a
    /// C function pointer and cannot capture context (Pitfall 3 in RESEARCH.md).
    /// Instance access is via the userInfo pointer (Unmanaged passUnretained).
    static let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
        // Handle tap-disabled-by-timeout: re-enable the tap (T-05-03)
        if type == .tapDisabledByTimeout {
            if let userInfo = userInfo {
                let listener = Unmanaged<ModifierHotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()
                if let tap = listener.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged, let userInfo = userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let listener = Unmanaged<ModifierHotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()
        let currentFlags = event.flags

        // Capture previous/current and combo config atomically on this thread
        let previous = listener.previousFlags
        listener.previousFlags = currentFlags

        let plain = listener.plainDictationCombo
        let cleanup = listener.cleanupCombo

        if let transition = ModifierHotkeyListener.detectTransition(
            from: previous,
            to: currentFlags,
            plainCombo: plain,
            cleanupCombo: cleanup
        ) {
            let mode = transition.mode
            let isPress = transition.isPress

            // Dispatch to MainActor for HotkeyManager interaction (non-blocking)
            DispatchQueue.main.async {
                if isPress {
                    listener.onComboActivated?(mode)
                } else {
                    listener.onComboReleased?(mode)
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Lifecycle

    /// Start the CGEventTap on a dedicated background thread.
    ///
    /// Silently returns if Accessibility permission is not granted (T-05-02).
    func start() {
        // Only listen for flagsChanged events — never sees keystrokes (T-05-01)
        let eventMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        // Pass self as userInfo — C-compatible pointer, unretained (self owns the tap)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,        // T-05-01: never modifies events
            eventsOfInterest: eventMask,
            callback: Self.callback,
            userInfo: userInfo
        ) else {
            // Accessibility permission not granted — silent failure (T-05-02)
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.runLoopSource = source

        // Run the tap on a dedicated background thread so the callback never
        // blocks the main thread (T-05-03)
        Thread.detachNewThread { [weak self] in
            guard let self else { return }
            let rl = CFRunLoopGetCurrent()!
            self.runLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
    }

    /// Stop the CGEventTap and shut down the background run loop.
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = runLoop {
            CFRunLoopStop(rl)
        }
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        previousFlags = []
    }

    // MARK: - Pure transition detection (testable)

    /// Detect a combo press or release from a CGEventFlags transition.
    ///
    /// Pure function — no side effects, no hardware needed. Designed for unit testing.
    ///
    /// Logic:
    /// 1. Filter both previous and current flags to only the four relevant modifiers
    ///    (Fn, Shift, Control, Option). Ignores Caps Lock, Command, etc.
    /// 2. For each combo (plain, cleanup):
    ///    - Activation: current filtered flags EXACTLY match the combo flags AND
    ///      previous filtered flags did NOT fully contain the combo.
    ///      The "exactly match" check prevents Fn+Shift+Control from activating fnShift.
    ///    - Release: previous filtered flags fully contained the combo AND
    ///      current filtered flags do NOT fully contain it.
    ///
    /// - Parameters:
    ///   - previous: CGEventFlags before the transition
    ///   - current: CGEventFlags after the transition
    ///   - plainCombo: the combo assigned to plain dictation mode
    ///   - cleanupCombo: the combo assigned to AI cleanup mode
    /// - Returns: A `(mode, isPress)` tuple if a transition was detected, nil otherwise.
    static func detectTransition(
        from previous: CGEventFlags,
        to current: CGEventFlags,
        plainCombo: ModifierCombo,
        cleanupCombo: ModifierCombo
    ) -> (mode: DictationMode, isPress: Bool)? {
        // Only consider these four modifier flags — ignore unrelated bits
        let relevantMask: CGEventFlags = [
            .maskSecondaryFn,
            .maskShift,
            .maskControl,
            .maskAlternate
        ]

        let prev = previous.intersection(relevantMask)
        let curr = current.intersection(relevantMask)

        // Check each combo in priority order (plain first, then cleanup)
        for (combo, mode) in [(plainCombo, DictationMode.plain), (cleanupCombo, DictationMode.aiCleanup)] {
            let comboFlags = combo.flags

            // Activation: current == exactly combo flags AND previous didn't have the full combo
            let comboActiveNow = curr == comboFlags
            let comboWasActive = prev.isSuperset(of: comboFlags)

            if comboActiveNow && !comboWasActive {
                return (mode: mode, isPress: true)
            }

            // Release: previous had all combo flags AND current is missing at least one
            if comboWasActive && !curr.isSuperset(of: comboFlags) {
                return (mode: mode, isPress: false)
            }
        }

        return nil
    }
}
