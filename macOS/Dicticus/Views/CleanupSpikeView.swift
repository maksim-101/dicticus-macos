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
                        Text("Variant (a)\ndrop ref list").bold()
                        Text("Variant (b)\ndrop trap list").bold()
                        Text("Variant (c)\nminimal").bold()
                        Text("Variant (d)\n(a) + few-shot").bold()
                    }
                    Divider().gridCellColumns(5)
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
                SpikeFixtures.buildVariantA,
                SpikeFixtures.buildVariantB,
                SpikeFixtures.buildVariantC,
                SpikeFixtures.buildVariantD
            ]
            for (vIdx, variant) in variants.enumerated() {
                progress = "Input \(i + 1)/\(inputs.count) — variant \(vIdx + 1)/4..."
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

    /// Variant (a): drop SwissHelvetisms reference list, keep negative trap list, reframe to one-way directive.
    /// Per RESEARCH.md §1 lines 113-118 (verbatim).
    static func buildVariantA(_ input: String) -> String {
        return """
        <start_of_turn>user
        INSTRUCTION: Lightly edit the following German dictation for grammar, punctuation, and capitalization. Do not paraphrase.
        LANGUAGE: de
        STYLE: Use Swiss German orthography (never use ß, always ss). Use Swiss thousands separator style (e.g. 1'250, not 1.250).
        RULE: Output Standard High German words and grammar. Apply Swiss orthography conventions only. Do NOT replace any High German word with its Swiss German dialect form. Forbidden substitutions include: auf→uf, ausgeflogen→usgfloge, gekostet→choschtet, einkaufen→iikaufe, natürlich→natürli, Dingen→Sache, gegessen→gässe, später→speter, beiden→beidne, Seite→Siite, etwas→öppis, Kleines→chliins, gekauft→chauft.
        INPUT: \(input)
        OUTPUT:<end_of_turn>
        <start_of_turn>model
        """
    }

    /// Variant (b): drop trap list, keep SwissHelvetisms reference list.
    /// Per RESEARCH.md §1 lines 122-126.
    static func buildVariantB(_ input: String) -> String {
        let ref = SwissHelvetisms.words.joined(separator: ", ")
        return """
        <start_of_turn>user
        INSTRUCTION: Lightly edit the following German dictation for grammar, punctuation, and capitalization. Do not paraphrase.
        LANGUAGE: de
        STYLE: Use Swiss German orthography (never use ß, always ss). Use Swiss thousands separator style (e.g. 1'250, not 1.250).
        RULE: Output Standard High German words and grammar. Apply Swiss orthography conventions only. Do NOT replace any High German word with its Swiss German dialect form.
        REFERENCE: When the speaker uses one of these Swiss substantive words, keep it: \(ref).
        INPUT: \(input)
        OUTPUT:<end_of_turn>
        <start_of_turn>model
        """
    }

    /// Variant (c): minimal — drop both lists, single one-way directive.
    /// Per RESEARCH.md §1 lines 130-133.
    static func buildVariantC(_ input: String) -> String {
        return """
        <start_of_turn>user
        INSTRUCTION: Lightly edit the following German dictation for grammar, punctuation, and capitalization. Do not paraphrase.
        LANGUAGE: de
        STYLE: Use Swiss German orthography (never use ß, always ss). Use Swiss thousands separator style (e.g. 1'250, not 1.250).
        RULE: Output Standard High German words and grammar. Apply Swiss orthography conventions only. Do NOT replace any High German word with its Swiss German dialect form.
        INPUT: \(input)
        OUTPUT:<end_of_turn>
        <start_of_turn>model
        """
    }

    /// Variant (d): variant (a) + few-shot positive examples.
    /// Per RESEARCH.md §1 lines 137-145.
    static func buildVariantD(_ input: String) -> String {
        return """
        <start_of_turn>user
        INSTRUCTION: Lightly edit the following German dictation for grammar, punctuation, and capitalization. Do not paraphrase.
        LANGUAGE: de
        STYLE: Use Swiss German orthography (never use ß, always ss). Use Swiss thousands separator style (e.g. 1'250, not 1.250).
        RULE: Output Standard High German words and grammar. Apply Swiss orthography conventions only. Do NOT replace any High German word with its Swiss German dialect form.
        EXAMPLES:
        INPUT: auf der anderen Seite
        OUTPUT: auf der anderen Seite
        INPUT: ich bin am Freitag ausgeflogen und habe etwas gekauft
        OUTPUT: ich bin am Freitag ausgeflogen und habe etwas gekauft
        INPUT: \(input)
        OUTPUT:<end_of_turn>
        <start_of_turn>model
        """
    }
}
#endif
