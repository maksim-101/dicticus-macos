import Foundation

/// Phase 36.1 Plan 05: Post-LLM number-form revert.
///
/// After the LLM runs, the deterministic layer owns number forms: any digit↔word
/// change the LLM introduced vs. the ITN baseline reverts to the baseline form.
/// Two count-budgeted passes over space-tokens cover both directions:
///   - LLM re-spelled a digit → revert to digit
///   - LLM promoted a spelled number-word to a digit → revert to word
///
/// Implementation is in Plan 36.1-05. This file is a compilable stub so the
/// test target builds before Plan 05 lands (Wave 0 RED scaffolding approach).
public enum NumberRevert {

    public struct Change {
        public let from: String
        public let to: String
    }

    /// Revert digit↔word changes the LLM introduced relative to `baseline`.
    /// Returns the corrected text and a list of changes applied.
    /// Stub: returns output unchanged (NumberRevertTests will fail RED until Plan 05).
    public static func apply(
        baseline: String,
        output: String,
        language: String
    ) -> (text: String, changes: [Change]) {
        // Plan 36.1-05 implements the full count-budgeted revert logic.
        return (text: output, changes: [])
    }
}
