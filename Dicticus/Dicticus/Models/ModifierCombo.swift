import CoreGraphics

/// Preset modifier-only hotkey combinations based on the Fn key.
///
/// These combos are detected via CGEventTap (not KeyboardShortcuts, which cannot
/// capture modifier-only combos). The listener runs in parallel with KeyboardShortcuts
/// per D-08 in 05-CONTEXT.md.
///
/// Defaults: fnShift for plain dictation, fnControl for AI cleanup (D-09).
enum ModifierCombo: CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case fnShift
    case fnControl
    case fnOption

    // MARK: - Identifiable

    var id: Self { self }

    // MARK: - CGEventFlags Mapping

    /// The CGEventFlags that must ALL be present (and only these relevant flags)
    /// for this combo to be considered active.
    var flags: CGEventFlags {
        switch self {
        case .fnShift:
            return [.maskSecondaryFn, .maskShift]
        case .fnControl:
            return [.maskSecondaryFn, .maskControl]
        case .fnOption:
            return [.maskSecondaryFn, .maskAlternate]
        }
    }

    // MARK: - Display

    /// User-facing label shown in the settings picker.
    var displayName: String {
        switch self {
        case .fnShift:
            return "Fn + Shift"
        case .fnControl:
            return "Fn + Control"
        case .fnOption:
            return "Fn + Option"
        }
    }
}
