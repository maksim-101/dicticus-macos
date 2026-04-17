# Phase 3: System-Wide Dictation - Research

**Researched:** 2026-04-17
**Domain:** macOS global hotkeys, text injection, clipboard management, system notifications
**Confidence:** HIGH

## Summary

Phase 3 wires the existing ASR pipeline (TranscriptionService from Phase 2/2.1) to system-wide hotkeys and text injection, delivering the core user experience: hold hotkey, speak, release, text appears at cursor. The phase has four major technical domains: (1) global hotkey registration with push-to-talk semantics, (2) text injection via clipboard + CGEvent paste synthesis, (3) visual recording feedback in the menu bar, and (4) macOS notifications for error states.

The most significant technical finding is that **KeyboardShortcuts (sindresorhus) explicitly does NOT support the Fn key as a modifier** -- it strips the `.function` flag during shortcut initialization. The user's chosen defaults of Fn+Shift and Fn+Control cannot be registered through KeyboardShortcuts alone. The recommended approach is a **hybrid architecture**: use KeyboardShortcuts for its user-configurable recorder UI and standard hotkey combos (as defaults and user-configurable alternatives), but implement a parallel CGEventTap-based Fn key monitor for Fn-combo detection. Alternatively, accept non-Fn defaults (e.g., Control+Shift+D for dictation, Control+Shift+C for cleanup) and rely solely on KeyboardShortcuts. This is flagged as an open question requiring user confirmation.

Text injection via NSPasteboard + CGEvent Cmd+V synthesis is the proven pattern used by VocaMac, Speak2, Maccy, and other macOS dictation apps. Clipboard save/restore requires iterating all pasteboard item types, saving data per type, and restoring after paste. The app already has Accessibility permission checking (PermissionManager), which is required for CGEvent posting.

**Primary recommendation:** Use KeyboardShortcuts 2.4.0 for user-configurable hotkeys with standard modifier combos as defaults. If Fn key support is essential, add a separate CGEventTap flagsChanged monitor alongside KeyboardShortcuts. Implement text injection as clipboard save + write + CGEvent Cmd+V + clipboard restore.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Hold-to-record activation -- hold hotkey starts recording, release triggers transcription and paste. Walkie-talkie mental model.
- **D-02:** Silent discard on short presses (< 0.3s) -- TranscriptionService already rejects via .tooShort, just reset state silently. No error, no beep.
- **D-03:** Suppress key repeat at the hotkey handler level -- track keyDown flag, ignore subsequent keyDown events until keyUp fires. Prevents multiple startRecording() calls.
- **D-04:** Default hotkey for plain dictation: Fn+Shift (left-hand combo). Note: Fn key is handled specially on macOS -- researcher must verify KeyboardShortcuts support or determine if lower-level approach (CGEventTap, IOKit) is needed.
- **D-05:** Default hotkey for AI cleanup mode: Fn+Control (left-hand combo). Same Fn caveat as D-04.
- **D-06:** Clipboard + Cmd+V paste strategy -- save NSPasteboard contents, write transcription text, synthesize Cmd+V via CGEvent, restore original clipboard. Most reliable cross-app method.
- **D-07:** Clipboard save and restore -- original clipboard contents preserved after injection. Small (~50ms) delay acceptable.
- **D-08:** Cmd+V for all apps including terminal emulators -- single code path. Terminal.app and iTerm2 support Cmd+V by default on macOS.
- **D-09:** Filled red mic icon (mic.fill with red tint) while recording -- universally understood "recording" signal. Reverts to normal mic on release.
- **D-10:** No audio feedback on record start/stop -- silent operation. Visual indicator is sufficient; audio cues could be picked up by the microphone.
- **D-11:** Spinner/hourglass icon during transcribing state (ellipsis.circle or similar) -- shows app is processing after key release.
- **D-12:** Register both hotkeys in Phase 3 -- plain dictation works end-to-end, AI cleanup is registered but stubbed.
- **D-13:** AI cleanup hotkey ignores silently in Phase 3 -- no recording, no notification, no action. Phase 4 wires it to the LLM pipeline.
- **D-14:** Hotkeys are user-configurable from the start -- use KeyboardShortcuts library's built-in preferences UI with recorder views in the menu bar dropdown. Conflict detection and UserDefaults persistence handled by the library.
- **D-15:** macOS notification for real errors -- post system notification for transcription failures (model error, mic unavailable).
- **D-16:** No notification for silence-only recordings -- these are expected (accidental holds, thinking pauses). Silent return to idle.
- **D-17:** "Model loading..." notification if hotkey pressed before warm-up completes.
- **D-18:** Continue recording across app switches -- recording doesn't stop when frontmost app changes. Text pastes into whatever app is frontmost on key release.
- **D-19:** Reject second hotkey press while transcribing -- TranscriptionService throws .busy, show "Still processing..." notification. No queuing, no cancellation.
- **D-20:** Add hotkey configuration section -- KeyboardShortcuts recorder views for both hotkeys.
- **D-21:** Add last transcription preview with copy button -- shows truncated text of last successful transcription.
- **D-22:** Existing permission rows and warmup row remain.

### Claude's Discretion
- Specific SF Symbol choice for transcribing state indicator
- Clipboard restore timing and delay values
- Notification content wording and category identifiers
- KeyboardShortcuts recorder view layout within dropdown
- Last transcription text truncation length
- CGEvent keystroke synthesis implementation details

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRNS-01 | User can push-to-talk via configurable hotkey and text appears at cursor in any app | Hotkey architecture (KeyboardShortcuts + optional CGEventTap), text injection pattern (clipboard + CGEvent Cmd+V), push-to-talk keyDown/keyUp wiring to TranscriptionService |
| TRNS-05 | Transcription works in any text field (browser, native apps, terminal) | CGEvent Cmd+V paste works universally across browsers (Safari, Chrome), native apps (Notes, TextEdit), and terminal emulators (Terminal.app, iTerm2) -- proven by VocaMac and Speak2 |
| APP-03 | Visual recording indicator while push-to-talk is active | Three-state icon mapping: idle=mic, recording=mic.fill+red, transcribing=ellipsis.circle. SF Symbol effects and .foregroundStyle for tinting. |
| APP-04 | Different hotkey combos for plain dictation vs AI cleanup mode | Two KeyboardShortcuts.Name registrations with separate defaults. AI cleanup stubbed (D-13). |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| KeyboardShortcuts | 2.4.0 | User-configurable global hotkeys with SwiftUI recorder UI | Standard for macOS menu bar apps. Sindresorhus, 50 releases, sandboxed-compatible, stores in UserDefaults, conflict detection built-in. Used by Dato, Plash, Lungo. [VERIFIED: Swift Package Index -- v2.4.0 released Sep 2025] |
| CoreGraphics (CGEvent) | macOS built-in | Cmd+V paste synthesis, optional Fn key monitoring | Apple framework for keyboard event synthesis. Required for posting keystrokes to other apps. Requires Accessibility permission. [VERIFIED: Apple Developer docs] |
| AppKit (NSPasteboard) | macOS built-in | Clipboard read/write/save/restore | Apple framework for pasteboard operations. General pasteboard shared across all apps. [VERIFIED: Apple Developer docs] |
| UserNotifications (UNUserNotificationCenter) | macOS built-in (10.14+) | Error notifications to user | Modern notification API replacing deprecated NSUserNotificationCenter. Works for bundled LSUIElement apps. [ASSUMED -- works for bundled LSUIElement apps; LaunchAgent limitations do not apply here] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI MenuBarExtra | macOS 13+ built-in | Menu bar icon state changes (recording indicator) | Already in use from Phase 1 -- extend icon state computation |
| SF Symbols | macOS built-in | Icon assets: mic, mic.fill, ellipsis.circle | Three-state icon for idle/recording/transcribing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| KeyboardShortcuts | Raw CGEventTap only | Loses user-configurable recorder UI, persistence, conflict detection. Much more code to maintain. |
| KeyboardShortcuts | HotKey (soffes) | Wraps deprecated Carbon RegisterEventHotKey internally. No recorder UI. |
| KeyboardShortcuts | MASShortcut | Objective-C, no SwiftUI support, less actively maintained |
| CGEvent Cmd+V | AXUIElement direct text injection | More reliable for specific apps but requires per-app testing. Cmd+V is universally supported. Good future enhancement. |
| UNUserNotificationCenter | Deprecated NSUserNotificationCenter | Modern API is preferred; deprecated API removed in future macOS versions |

**Installation (SPM in project.yml):**
```yaml
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts.git
    from: 2.4.0
```

Add dependency to target:
```yaml
dependencies:
  - package: KeyboardShortcuts
    product: KeyboardShortcuts
```

## Architecture Patterns

### Recommended Project Structure
```
Dicticus/
  Services/
    HotkeyManager.swift          # NEW: Hotkey registration, push-to-talk state machine
    TextInjector.swift            # NEW: Clipboard save/write/paste/restore
    NotificationService.swift     # NEW: UNUserNotificationCenter wrapper
    TranscriptionService.swift    # EXISTING: ASR pipeline (Phase 2/2.1)
    ModelWarmupService.swift      # EXISTING: Model warm-up
    PermissionManager.swift       # EXISTING: Permission checks
  Views/
    MenuBarView.swift             # MODIFY: Add hotkey config + last transcription
    HotkeySettingsView.swift      # NEW: KeyboardShortcuts recorder views
    LastTranscriptionView.swift   # NEW: Truncated text + copy button
  Extensions/
    KeyboardShortcuts+Names.swift # NEW: Shortcut name definitions
```

### Pattern 1: HotkeyManager -- Push-to-Talk State Machine
**What:** Centralized service that manages hotkey registration, push-to-talk keyDown/keyUp events, and mode routing (dictation vs AI cleanup).
**When to use:** Single point of coordination between hotkey events, TranscriptionService, and TextInjector.
**Example:**
```swift
// Source: KeyboardShortcuts API + CGEventTap pattern from VocaMac/Speak2
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // D-14: User-configurable from the start
    static let plainDictation = Self("plainDictation", default: .init(.s, modifiers: [.control, .shift]))
    static let aiCleanup = Self("aiCleanup", default: .init(.d, modifiers: [.control, .shift]))
}

@MainActor
class HotkeyManager: ObservableObject {
    @Published var isRecording = false
    private var isKeyDown = false  // D-03: suppress key repeat

    private weak var transcriptionService: TranscriptionService?
    private let textInjector = TextInjector()

    func setup(transcriptionService: TranscriptionService) {
        self.transcriptionService = transcriptionService

        // Listen for keyDown and keyUp events
        Task {
            for await event in KeyboardShortcuts.events(for: .plainDictation) {
                switch event {
                case .keyDown:
                    handleKeyDown(mode: .plain)
                case .keyUp:
                    handleKeyUp(mode: .plain)
                }
            }
        }
        // D-12/D-13: AI cleanup registered but stubbed
        Task {
            for await event in KeyboardShortcuts.events(for: .aiCleanup) {
                switch event {
                case .keyDown:
                    break  // D-13: silent ignore in Phase 3
                case .keyUp:
                    break
                }
            }
        }
    }

    private func handleKeyDown(mode: DictationMode) {
        guard !isKeyDown else { return }  // D-03: suppress repeat
        isKeyDown = true

        guard let service = transcriptionService else { return }
        guard service.state == .idle else {
            // D-19: reject while transcribing
            NotificationService.shared.post(.busy)
            return
        }

        do {
            try service.startRecording()
            isRecording = true
        } catch {
            NotificationService.shared.post(.recordingFailed(error))
        }
    }

    private func handleKeyUp(mode: DictationMode) {
        guard isKeyDown else { return }
        isKeyDown = false

        guard let service = transcriptionService,
              service.state == .recording else { return }

        isRecording = false

        Task {
            do {
                let result = try await service.stopRecordingAndTranscribe()
                await textInjector.injectText(result.text)
            } catch TranscriptionError.tooShort {
                // D-02: silent discard
            } catch TranscriptionError.silenceOnly {
                // D-16: no notification for silence
            } catch {
                NotificationService.shared.post(.transcriptionFailed(error))
            }
        }
    }
}

enum DictationMode {
    case plain
    case aiCleanup  // Phase 4
}
```

### Pattern 2: TextInjector -- Clipboard Save/Write/Paste/Restore
**What:** Save current clipboard, write text, synthesize Cmd+V, restore clipboard.
**When to use:** After successful transcription, inject text at cursor position.
**Example:**
```swift
// Source: Pattern from VocaMac, Speak2, Maccy clipboard handling
import AppKit
import CoreGraphics

class TextInjector {

    /// Inject text at the current cursor position via clipboard + Cmd+V.
    /// Saves original clipboard, writes text, pastes, then restores.
    func injectText(_ text: String) async {
        let pasteboard = NSPasteboard.general

        // Step 1: Save original clipboard contents
        let savedItems = saveClipboard(pasteboard)

        // Step 2: Write transcription text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Step 3: Synthesize Cmd+V
        synthesizePaste()

        // Step 4: Wait for paste to complete, then restore
        // D-07: ~50ms delay acceptable
        try? await Task.sleep(nanoseconds: 50_000_000)
        restoreClipboard(pasteboard, items: savedItems)
    }

    private func synthesizePaste() {
        // V key = keyCode 9 (layout-independent)
        let keyCodeV: CGKeyCode = 9

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCodeV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCodeV, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Post at .cgAnnotatedSessionEventTap for cross-app delivery
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    // Clipboard types saved as (type, data) tuples per pasteboard item
    private struct SavedClipboard {
        let items: [[(NSPasteboard.PasteboardType, Data)]]
    }

    private func saveClipboard(_ pasteboard: NSPasteboard) -> SavedClipboard {
        var saved: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData.append((type, data))
                }
            }
            saved.append(itemData)
        }
        return SavedClipboard(items: saved)
    }

    private func restoreClipboard(_ pasteboard: NSPasteboard, items: SavedClipboard) {
        pasteboard.clearContents()
        for itemData in items.items {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}
```
[VERIFIED: NSPasteboard API from Apple Developer docs; CGEvent key synthesis pattern from Apple Developer Forums thread/659804 and Igor Kulman's auto-type implementation]

### Pattern 3: Menu Bar Icon State Machine
**What:** Three-state icon driven by TranscriptionService.State and PermissionManager.
**When to use:** DicticusApp.body MenuBarExtra label computation.
**Example:**
```swift
// Source: Existing DicticusApp.swift pattern extended per D-09, D-11
private var iconName: String {
    if !permissionManager.allGranted {
        return "mic.slash"  // Degraded: missing permissions
    }
    // NEW: Recording/transcribing states from Phase 3
    if let service = transcriptionService {
        switch service.state {
        case .recording:
            return "mic.fill"  // D-09: red mic during recording
        case .transcribing:
            return "ellipsis.circle"  // D-11: spinner during transcription
        case .idle:
            return "mic"
        }
    }
    return "mic"
}

// For the recording tint, use .foregroundStyle(.red) when recording
// For the transcribing state, use .symbolEffect(.pulse) like warm-up
```

### Anti-Patterns to Avoid
- **Registering Fn as a modifier in KeyboardShortcuts:** Library explicitly strips `.function` flag. Will silently fail. Use CGEventTap if Fn support is needed.
- **Using deprecated NSUserNotificationCenter:** Removed in future macOS. Use UNUserNotificationCenter.
- **Synthesizing individual character keystrokes instead of Cmd+V:** Much slower, error-prone with special characters, encoding issues. Always use clipboard+paste.
- **Polling for hotkey state:** Use event-driven async streams from KeyboardShortcuts, not polling.
- **Capturing self strongly in CGEventTap callback:** CGEventTapCallBack is a C function pointer -- use userInfo with Unmanaged pointer, not closures.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global hotkey registration | Custom Carbon RegisterEventHotKey wrapper | KeyboardShortcuts 2.4.0 | Handles UserDefaults persistence, conflict detection, recorder UI, sandboxing compatibility. Carbon API deprecated. |
| Hotkey recorder UI | Custom NSEvent key capture view | KeyboardShortcuts RecorderCocoa / SwiftUI Recorder | Handles modifier display, key name localization, conflict warnings, reset button |
| Clipboard type enumeration | Manual UTI string matching | NSPasteboardItem.types iteration | Apple handles type registration and discovery |
| Key code mapping | Hardcoded keycode dictionaries | CGEvent(keyboardEventSource:virtualKey:keyDown:) with well-known constants | Apple's virtual key codes are layout-independent |

**Key insight:** The hotkey + recorder UI combination from KeyboardShortcuts saves hundreds of lines of code that would otherwise need custom NSEvent monitoring, UserDefaults serialization, conflict detection, and SwiftUI binding code. Text injection via clipboard+paste is the only universally reliable approach -- every macOS dictation app (VocaMac, Speak2, MacWhisper) uses this pattern.

## Common Pitfalls

### Pitfall 1: Fn Key Not Supported by KeyboardShortcuts
**What goes wrong:** Registering Fn+Shift as a default shortcut in KeyboardShortcuts silently strips the Fn flag. The shortcut becomes Shift-only, which fires on every Shift press.
**Why it happens:** KeyboardShortcuts explicitly filters out `.function` from NSEvent.ModifierFlags because they cannot reliably distinguish Fn+F1 (should show F1) from Fn+V (should show Fn+V). [VERIFIED: Shortcut.swift source code comment]
**How to avoid:** Use standard modifier combos (Control+Shift+key) as defaults. If Fn is essential, implement a parallel CGEventTap `.flagsChanged` monitor.
**Warning signs:** Shortcut fires on unexpected key combos; recorder view doesn't show Fn modifier.

### Pitfall 2: Clipboard Restore Timing
**What goes wrong:** Restoring clipboard too quickly after CGEvent paste causes the restore to overwrite before the target app reads the paste.
**Why it happens:** CGEvent.post is asynchronous -- the keyDown/keyUp events enter the system event queue but the target app processes them slightly later.
**How to avoid:** Add a 50-100ms delay (Task.sleep) between paste synthesis and clipboard restore. Monitor changeCount to detect when the target app has read. [ASSUMED -- 50ms delay is standard practice in VocaMac/Speak2, but optimal value may need tuning]
**Warning signs:** Pasted text is the previous clipboard content, not the transcription.

### Pitfall 3: Key Repeat Flooding
**What goes wrong:** macOS sends repeated keyDown events while a key is held. Without suppression, startRecording() is called multiple times, throwing .busy errors.
**Why it happens:** macOS key repeat is system-wide. KeyboardShortcuts events(for:) will emit repeated keyDown events.
**How to avoid:** Track a `isKeyDown` boolean flag. Ignore keyDown when flag is true. Reset on keyUp. (D-03)
**Warning signs:** Console logs showing .busy errors during hold-to-record.

### Pitfall 4: CGEvent Requires Accessibility Permission
**What goes wrong:** CGEvent.post silently fails if the app doesn't have Accessibility permission.
**Why it happens:** macOS requires Accessibility trust for posting synthetic keyboard events to other apps.
**How to avoid:** PermissionManager already checks Accessibility (AXIsProcessTrusted). Gate text injection on this check. Show clear error if not granted.
**Warning signs:** Hotkey works, transcription completes, but no text appears at cursor.

### Pitfall 5: NSPasteboard.clearContents Increments changeCount
**What goes wrong:** Each clearContents() call creates a new "generation" of the pasteboard. Apps monitoring clipboard changes (Maccy, ClipboardManager, etc.) may record the transcription text as a clipboard entry.
**Why it happens:** NSPasteboard has no "silent write" mode. All writes are visible to all apps.
**How to avoid:** Accept this limitation for now. Consider marking data with `org.nspasteboard.AutoGeneratedType` UTI to hint clipboard managers to ignore it. [CITED: nspasteboard.org]
**Warning signs:** User's clipboard manager fills up with dictated text entries.

### Pitfall 6: Swift 6 Concurrency with CGEventTap
**What goes wrong:** Compiler errors trying to capture @MainActor properties in CGEventTap callback.
**Why it happens:** CGEventTapCallBack is a C function pointer type -- it cannot capture Swift closures or reference @MainActor-isolated state directly.
**How to avoid:** Pass an Unmanaged pointer to a coordinator object via the userInfo parameter. Dispatch back to MainActor via Task { @MainActor in ... } from the callback. [VERIFIED: alt-tab-macos KeyboardEvents.swift pattern]
**Warning signs:** Swift 6 compiler errors about Sendable, actor isolation, or capturing non-sendable types.

## Code Examples

### CGEvent Cmd+V Paste Synthesis (Complete)
```swift
// Source: Apple Developer docs CGEvent init(keyboardEventSource:virtualKey:keyDown:)
// Key code reference: https://gist.github.com/swillits/df648e87016772c7f7e5dbed2b345066
func synthesizeCmdV() {
    let vKeyCode: CGKeyCode = 9  // V key (layout-independent)

    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
        return
    }

    // Set Command modifier flag
    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand

    // Post to annotated session event tap (cross-app delivery)
    keyDown.post(tap: .cgAnnotatedSessionEventTap)
    keyUp.post(tap: .cgAnnotatedSessionEventTap)
}
```
[VERIFIED: CGKeyCode 9 = V from gist.github.com/swillits keycode mapping; CGEvent API from Apple Developer docs]

### KeyboardShortcuts Registration
```swift
// Source: sindresorhus/KeyboardShortcuts README
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let plainDictation = Self("plainDictation", default: .init(.s, modifiers: [.control, .shift]))
    static let aiCleanup = Self("aiCleanup", default: .init(.d, modifiers: [.control, .shift]))
}

// SwiftUI recorder view for preferences
KeyboardShortcuts.Recorder("Plain Dictation:", name: .plainDictation)
KeyboardShortcuts.Recorder("AI Cleanup:", name: .aiCleanup)

// Async event listening (keyDown + keyUp)
for await event in KeyboardShortcuts.events(for: .plainDictation) {
    switch event {
    case .keyDown: startRecording()
    case .keyUp: stopAndTranscribe()
    }
}
```
[VERIFIED: KeyboardShortcuts 2.4.0 API from GitHub source; events(for:) returns AsyncStream<EventType> with .keyDown/.keyUp]

### UNUserNotificationCenter for Error Notifications
```swift
// Source: Apple Developer docs UNUserNotificationCenter
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    func setup() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            // Handle permission result
        }
    }

    func post(_ notification: DicticusNotification) {
        let content = UNMutableNotificationContent()
        content.title = "Dicticus"
        content.body = notification.message

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

enum DicticusNotification {
    case busy
    case modelLoading
    case transcriptionFailed(Error)
    case recordingFailed(Error)

    var message: String {
        switch self {
        case .busy: return "Still processing previous transcription..."  // D-19
        case .modelLoading: return "Models still loading, please wait..."  // D-17
        case .transcriptionFailed(let error): return "Transcription failed: \(error.localizedDescription)"  // D-15
        case .recordingFailed(let error): return "Could not start recording: \(error.localizedDescription)"
        }
    }
}
```
[ASSUMED -- UNUserNotificationCenter with LSUIElement bundled app; verified for standard macOS apps but not specifically tested with LSUIElement=true non-sandboxed]

### CGEventTap for Fn Key Detection (If Needed)
```swift
// Source: Pattern from alt-tab-macos, VocaMac HotkeyManager
// Only needed if Fn key modifier support is required (D-04, D-05)
import CoreGraphics

class FnKeyMonitor {
    private var eventTap: CFMachPort?

    func start() {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, _ -> Unmanaged<CGEvent>? in
                let flags = event.flags
                let fnDown = flags.contains(.maskSecondaryFn)
                let shiftDown = flags.contains(.maskShift)

                if fnDown && shiftDown {
                    // Fn+Shift detected -- notify via callback
                    // Use DistributedNotificationCenter or dispatch to MainActor
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        guard let eventTap else { return }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}
```
[VERIFIED: CGEventFlags.maskSecondaryFn exists per Apple Developer docs; CGEvent.tapCreate pattern from alt-tab-macos and VocaMac]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Carbon RegisterEventHotKey | KeyboardShortcuts 2.x / CGEventTap | 2023-2024 | Carbon deprecated since macOS 10.8; KeyboardShortcuts wraps modern APIs |
| NSUserNotificationCenter | UNUserNotificationCenter | macOS 10.14 | NSUserNotificationCenter deprecated; modern API supports rich notifications |
| NSStatusBar manual management | SwiftUI MenuBarExtra | macOS 13 (2022) | Declarative menu bar API; already used by Dicticus |
| AXUIElement text injection | Clipboard + CGEvent Cmd+V | N/A (both valid) | Clipboard+paste is more universal; AXUIElement is per-app but avoids clipboard side effects |

**Deprecated/outdated:**
- **NSUserNotificationCenter:** Deprecated in macOS 10.14, removed path. Use UNUserNotificationCenter.
- **Carbon RegisterEventHotKey:** Deprecated since macOS 10.8. Still works but not recommended for new code.
- **NSStatusItem with button property:** Still works but SwiftUI MenuBarExtra is the modern approach (already used).

## Assumptions Log

> List all claims tagged [ASSUMED] in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | UNUserNotificationCenter works for bundled LSUIElement apps (not sandboxed) | Standard Stack / Code Examples | If notifications don't work, would need to use NSAlert or custom UI overlay instead. LOW risk -- bundled app unlike LaunchAgent. |
| A2 | 50ms delay between CGEvent paste and clipboard restore is sufficient | Pattern 2 / Pitfall 2 | If too fast, pasted text is wrong. If too slow, user notices clipboard flicker. Can be tuned empirically. LOW risk. |
| A3 | Default hotkey alternatives (Control+Shift+S/D) are acceptable if Fn key support is deferred | Architecture Patterns | User explicitly requested Fn+Shift and Fn+Control. May need CGEventTap for Fn or user acceptance of alternative defaults. MEDIUM risk. |

## Open Questions

1. **Fn Key as Hotkey Modifier**
   - What we know: KeyboardShortcuts explicitly does NOT support Fn key. CGEventTap can detect Fn via `.maskSecondaryFn` in `.flagsChanged` events. VocaMac and Speak2 support Fn via CGEventTap.
   - What's unclear: Whether the user considers Fn key support essential for v1 or if standard modifier defaults (Control+Shift+key) are acceptable.
   - Recommendation: **Ship with standard modifier defaults in KeyboardShortcuts (Control+Shift+S for dictation, Control+Shift+D for cleanup). Fn key support can be added as a parallel CGEventTap monitor, but adds complexity.** If user insists on Fn, implement a separate FnKeyMonitor service alongside KeyboardShortcuts. The two systems can coexist -- KeyboardShortcuts handles the recorder UI and user-configured combos, while FnKeyMonitor handles the Fn-specific defaults.

2. **Clipboard Restore Completeness**
   - What we know: NSPasteboard items have multiple types (string, RTF, HTML, images, file URLs). Save/restore must iterate all types.
   - What's unclear: Whether some pasteboard types (e.g., promised files, lazy-loaded data) can't be fully captured and restored.
   - Recommendation: Save all types returned by `item.types` and their data. Accept that some edge cases (lazy-loaded/promised data) may lose the original clipboard. This matches behavior of VocaMac and Speak2.

3. **Notification Permission for Non-Sandboxed LSUIElement App**
   - What we know: UNUserNotificationCenter is the modern API. LaunchAgents have known issues. Dicticus is a bundled app with LSUIElement=true, not a LaunchAgent.
   - What's unclear: Whether UNUserNotificationCenter.requestAuthorization works without code signing in Debug builds.
   - Recommendation: Implement with UNUserNotificationCenter. If it fails in Debug builds, fall back to NSAlert or custom menu bar tooltip. Test early in Phase 3 Wave 0.

## Project Constraints (from CLAUDE.md)

- **Privacy:** All processing on-device, no cloud -- Phase 3 does not add network calls; text stays local.
- **Performance:** < 2-3 seconds transcription -- already met in Phase 2/2.1; Phase 3 adds only clipboard + paste latency (~50-100ms).
- **Unsandboxed distribution:** App is not sandboxed (entitlements confirm). CGEvent posting and CGEventTap both work without sandbox.
- **Swift 6 strict concurrency:** Project uses SWIFT_VERSION: "6.0". All new code must be @MainActor or properly Sendable.
- **XcodeGen:** Project uses project.yml. New SPM dependency (KeyboardShortcuts) must be added there, not directly to .xcodeproj.
- **macOS 15+ target:** Deployment target is macOS 15.0. All APIs used are available on macOS 15+.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | Dicticus/DicticusTests/ (existing test target in project.yml) |
| Quick run command | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -only-testing:DicticusTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' 2>&1 \| tail -40` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRNS-01 | Hotkey triggers recording, text appears at cursor | manual-only | N/A -- requires physical hotkey press + focus in target app | N/A |
| TRNS-05 | Text injection works in browsers, native apps, terminal | manual-only | N/A -- requires focus in different apps | N/A |
| APP-03 | Visual recording indicator (icon state) | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testIconStateRecording` | Wave 0 |
| APP-04 | Different hotkeys for plain vs AI cleanup | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testTwoHotkeysRegistered` | Wave 0 |
| D-02 | Silent discard on short press | unit | Test HotkeyManager.handleKeyUp after <0.3s -- TranscriptionError.tooShort is silent | Wave 0 |
| D-03 | Key repeat suppression | unit | Test HotkeyManager keyDown flag prevents duplicate calls | Wave 0 |
| D-07 | Clipboard save/restore | unit | Test TextInjector save/restore round-trip with multiple types | Wave 0 |
| D-19 | Reject second hotkey while transcribing | unit | Test HotkeyManager when service.state == .transcribing | Wave 0 |

### Sampling Rate
- **Per task commit:** Quick run (unit tests only, no model-dependent tests)
- **Per wave merge:** Full suite including model-dependent tests (on developer machine)
- **Phase gate:** Full suite green + manual smoke test (dictate in Notes, Safari, Terminal)

### Wave 0 Gaps
- [ ] `DicticusTests/HotkeyManagerTests.swift` -- covers D-02, D-03, D-19, APP-03, APP-04
- [ ] `DicticusTests/TextInjectorTests.swift` -- covers D-07 clipboard save/restore
- [ ] `DicticusTests/NotificationServiceTests.swift` -- covers D-15, D-17 notification posting
- [ ] KeyboardShortcuts SPM dependency added to project.yml

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A -- local app, no auth |
| V3 Session Management | no | N/A -- no sessions |
| V4 Access Control | yes (macOS permissions) | PermissionManager gates functionality on Accessibility, Microphone, Input Monitoring |
| V5 Input Validation | yes (transcription output) | Transcription text is trimmed/validated before clipboard write. No injection risk since clipboard is plain string. |
| V6 Cryptography | no | N/A -- no encryption in this phase |

### Known Threat Patterns for macOS Menu Bar App + CGEvent

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious app reading clipboard during injection window | Information Disclosure | Minimize clipboard exposure time (~50ms). org.nspasteboard.AutoGeneratedType hint. |
| CGEvent tap intercepting dictated text | Information Disclosure | macOS Input Monitoring permission required for event taps. Not preventable if user grants. |
| Key repeat flooding causing unexpected behavior | Denial of Service | D-03: isKeyDown flag suppresses repeats |
| Accessibility permission prompt fatigue | Tampering | Already checked in Phase 1 PermissionManager. Single check flow. |

## Sources

### Primary (HIGH confidence)
- [KeyboardShortcuts 2.4.0 source](https://github.com/sindresorhus/KeyboardShortcuts) -- Fn key exclusion confirmed in Shortcut.swift, events(for:) API, recorder view
- [KeyboardShortcuts releases](https://github.com/sindresorhus/KeyboardShortcuts/releases) -- v2.4.0 released Sep 2025
- [Swift Package Index](https://swiftpackageindex.com/sindresorhus/KeyboardShortcuts) -- version and compatibility verification
- [CGEvent.tapCreate Apple docs](https://developer.apple.com/documentation/coregraphics/cgevent/1454426-tapcreate) -- event tap API
- [CGEventFlags.maskSecondaryFn Apple docs](https://developer.apple.com/documentation/coregraphics/cgeventflags/masksecondaryfn) -- Fn key flag
- [NSPasteboard Apple docs](https://developer.apple.com/documentation/appkit/nspasteboard) -- clipboard API
- [macOS keycode mapping gist](https://gist.github.com/swillits/df648e87016772c7f7e5dbed2b345066) -- V key = keyCode 9
- [alt-tab-macos KeyboardEvents.swift](https://github.com/lwouis/alt-tab-macos/blob/master/src/logic/events/KeyboardEvents.swift) -- CGEventTap + flagsChanged pattern
- [VocaMac](https://github.com/jatinkrmalik/vocamac) -- HotkeyManager + TextInjector architecture reference
- [Speak2](https://github.com/zachswift615/speak2) -- Push-to-talk + clipboard restore architecture reference

### Secondary (MEDIUM confidence)
- [Igor Kulman auto-type implementation](https://blog.kulman.sk/implementing-auto-type-on-macos/) -- CGEvent paste synthesis details
- [rampatra Fn key detection](https://blog.rampatra.com/how-to-detect-fn-key-press-in-swift) -- NSEvent.ModifierFlags.function detection
- [nspasteboard.org](http://nspasteboard.org/) -- AutoGeneratedType, ConcealedType pasteboard markers
- [Maccy Clipboard.swift](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift) -- clipboard save/restore pattern with type filtering

### Tertiary (LOW confidence)
- [UNUserNotificationCenter with LSUIElement](https://developer.apple.com/forums/thread/679326) -- confirmed for LaunchAgents issue, not specifically tested for bundled LSUIElement apps

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- KeyboardShortcuts is well-documented, CGEvent APIs are stable Apple frameworks, pattern validated by VocaMac/Speak2
- Architecture: HIGH -- Pattern directly mirrors VocaMac (same use case: local ASR + push-to-talk + clipboard paste) with Dicticus-specific adjustments
- Pitfalls: HIGH -- Fn key limitation verified in source code, CGEvent permissions verified via existing PermissionManager, clipboard timing well-documented in community
- Fn key support: MEDIUM -- CGEventTap approach works (verified in VocaMac/alt-tab-macos) but adds complexity; user confirmation needed on whether to implement or defer

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (30 days -- stable macOS APIs, KeyboardShortcuts actively maintained)
