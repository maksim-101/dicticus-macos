#if DEBUG
import SwiftUI

/// DEBUG-only spike harness for Phase 20.08 prompt A/B comparison.
/// Per CONTEXT.md D-02/D-03/D-04 and RESEARCH.md §2.
/// Runs 5 fixture inputs x 4 prompt variants sequentially against the
/// loaded Gemma 4 E2B model with a pinned sampler seed (0xDEADBEEF) for
/// reproducibility, then renders a 4-column x 5-row grid for visual
/// comparison. User picks the variant that preserves Standard High German
/// on ALL 5 fixtures and records the choice in 20.08-SPIKE-RESULTS.md.
///
/// CONCURRENCY: inferences run sequentially due to CleanupService.isInferring
/// guard. UI shows a per-cell loading indicator while each inference runs.
struct CleanupSpikeView: View {

    @EnvironmentObject var cleanupService: CleanupService

    @State private var rows: [SpikeRow] = []
    @State private var isRunning: Bool = false
    @State private var progress: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Phase 20.08 Cleanup Spike")
                    .font(.headline)
                Spacer()
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(progress).font(.caption)
                }
                Button("Run Spike") {
                    Task { await runSpike() }
                }
                .disabled(isRunning || !cleanupService.isLoaded)
            }
            .padding()

            ScrollView {
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        Text("Input").bold()
                        Text("Variant (e)\nHigh German +\nSwiss orthography").bold()
                        Text("Variant (f)\n(e) + non-biasing\nfew-shot").bold()
                    }
                    Divider().gridCellColumns(3)
                    ForEach(rows) { row in
                        GridRow {
                            Text(row.input)
                                .font(.caption)
                                .frame(maxWidth: 240, alignment: .topLeading)
                                .textSelection(.enabled)
                            ForEach(row.outputs.indices, id: \.self) { idx in
                                Text(row.outputs[idx])
                                    .font(.caption)
                                    .frame(maxWidth: 220, alignment: .topLeading)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 1200, minHeight: 600)
    }

    private func runSpike() async {
        isRunning = true
        defer { isRunning = false }
        rows = []
        cleanupService.setSamplerSeed(0xDEADBEEF)
        defer { cleanupService.setSamplerSeed(nil) }

        let inputs = SpikeFixtures.inputs   // 5 fixtures
        for (i, input) in inputs.enumerated() {
            progress = "Input \(i + 1)/\(inputs.count)..."
            var outputs: [String] = []
            let variants: [(String) -> String] = [
                SpikeFixtures.buildVariantE,
                SpikeFixtures.buildVariantF
            ]
            for (vIdx, variant) in variants.enumerated() {
                progress = "Input \(i + 1)/\(inputs.count) — variant \(vIdx + 1)/2..."
                let prompt = variant(input)
                let out = await cleanupService.cleanupWithExplicitPrompt(prompt)
                outputs.append(out)
            }
            rows.append(SpikeRow(id: UUID(), input: input, outputs: outputs))
        }
        progress = "Done"
    }
}

struct SpikeRow: Identifiable {
    let id: UUID
    let input: String
    let outputs: [String]
}

/// Fixture inputs (5) + 4 variant prompt-builder helpers.
/// Per CONTEXT.md D-03 (5 inputs: UAT failure + 4 variations) and
/// RESEARCH.md §1 (4 variants a/b/c/d with concrete drafts).
enum SpikeFixtures {
    static let inputs: [String] = [
        // 1) The 2026-04-27 UAT failure utterance — anchor fixture.
        "Auf der anderen Seite war ich wahrscheinlich, alle meine, würde ich denn, hat, hier ausfiltern.",
        // 2) Short High German everyday utterance.
        "Heute war ich auf dem Markt einkaufen.",
        // 3) Long High German with multiple clauses.
        "Ich bin am Freitag ausgeflogen und habe etwas gekauft, das natürlich teurer war als gedacht.",
        // 4) High German with currency (intersection with Phase 20.06 anti-flip).
        "Das hat mich dann ungefähr vier Franken fünfzig gekostet.",
        // 5) Pure High German short with subjunctive (a known Swiss-form trigger).
        "Ich wäre gerne früher zu Hause gewesen."
    ]

    /// Variant (e): single-rule "Standard High German + Swiss orthography only".
    /// New contract per user 2026-04-28: do NOT preserve Swiss vocabulary at all
    /// (drop helvetism reference list, drop dialect-form trap list). Cleanup
    /// goal is plain Standard High German with only orthographic adaptation.
    /// The Plan 02 helvetism-delta gate catches any dialect leakage.
    static func buildVariantE(_ input: String) -> String {
        return """
        <start_of_turn>user
        INSTRUCTION: Edit the following German dictation for grammar, punctuation, and capitalization. Do not paraphrase. Do not substitute any word with a different word.
        LANGUAGE: de
        RULE 1: Output Standard High German words and grammar exactly as dictated.
        RULE 2: Apply Swiss orthography only — write ss instead of ß; write thousands as 1'250 not 1.250.
        INPUT: \(input)
        OUTPUT:<end_of_turn>
        <start_of_turn>model
        """
    }

    /// Variant (f): variant (e) + non-biasing few-shot.
    /// Each example demonstrates one rule (ß→ss, identity preservation,
    /// thousands separator) with diverse content so the model cannot copy
    /// any specific phrase — sidesteps the variant (d) collapse where
    /// few-shot examples bled into outputs.
    static func buildVariantF(_ input: String) -> String {
        return """
        <start_of_turn>user
        INSTRUCTION: Edit the following German dictation for grammar, punctuation, and capitalization. Do not paraphrase. Do not substitute any word with a different word.
        LANGUAGE: de
        RULE 1: Output Standard High German words and grammar exactly as dictated.
        RULE 2: Apply Swiss orthography only — write ss instead of ß; write thousands as 1'250 not 1.250.
        EXAMPLES:
        INPUT: das war groß und teuer
        OUTPUT: das war gross und teuer
        INPUT: ich gehe morgen einkaufen
        OUTPUT: ich gehe morgen einkaufen
        INPUT: 1.250 Franken sind genug
        OUTPUT: 1'250 Franken sind genug
        INPUT: \(input)
        OUTPUT:<end_of_turn>
        <start_of_turn>model
        """
    }
}
#endif
