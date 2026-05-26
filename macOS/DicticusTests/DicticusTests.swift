import XCTest
@testable import Dicticus

final class DicticusTests: XCTestCase {
    func testPlaceholder() throws {
        XCTAssertTrue(true)
    }
}

#if DEBUG_RECORDER
/// Phase 27-02: Codable round-trip contract for DebugCleanupRecord with the
/// new dictionary_replacements + dictionary_blocked fields (D-06, D-07).
///
/// Pins the JSONL schema: empty arrays must serialize to literal `[]`
/// (not absent keys) so downstream log analyses can rely on every record
/// carrying both fields. Populated entries must round-trip with full field
/// fidelity including the Double-valued `ratio` (within accuracy 0.001).
///
/// Cross-platform parity (feedback_cleanup_cross_platform_parity): byte-
/// identical between macOS and iOS test targets.
@MainActor
final class DebugCleanupRecordCodableTests: XCTestCase {

    func testDebugCleanupRecordCodableRoundTrip_DefaultEmpty() {
        let record = DebugCleanupRecord(
            ts: "2026-05-26T12:00:00.000Z",
            session_id: "test-session",
            lang: "en",
            lang_used: "en",
            mode: "plain",
            model: DebugCleanupRecord.ModelInfo(name: "test", sha256_prefix: nil),
            sampler: DebugCleanupRecord.SamplerInfo(temp: 0.1, top_k: 1, top_p: 1.0, max_tokens: 1, seed: nil),
            steps: DebugCleanupRecord.Steps(
                raw: DebugCleanupRecord.StepEntry(text: "", ms: 0),
                post_dict: DebugCleanupRecord.StepEntry(text: "", ms: 0),
                post_itn: DebugCleanupRecord.StepEntry(text: "", ms: 0),
                post_swiss: DebugCleanupRecord.StepEntry(text: "", ms: 0),
                post_rules: DebugCleanupRecord.StepEntry(text: "", ms: 0),
                llm_prompt: nil,
                llm_raw: nil,
                post_gate: nil,
                post_swiss_num: DebugCleanupRecord.StepEntry(text: "", ms: 0)
            ),
            dictionary_context_keys: [],
            dictionary_replacements: [],
            dictionary_blocked: [],
            anomaly: DebugCleanupRecord.Anomaly(degenerate_collapse: false, very_short_output: false),
            emission_counter: 0
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(record)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"dictionary_replacements\":[]"),
            "Phase 27-02: empty dictionary_replacements must serialize to literal [] (not absent) — got: \(json)")
        XCTAssertTrue(json.contains("\"dictionary_blocked\":[]"),
            "Phase 27-02: empty dictionary_blocked must serialize to literal [] (not absent) — got: \(json)")

        let decoder = JSONDecoder()
        let roundtrip = try! decoder.decode(DebugCleanupRecord.self, from: data)
        XCTAssertTrue(roundtrip.dictionary_replacements.isEmpty)
        XCTAssertTrue(roundtrip.dictionary_blocked.isEmpty)
    }

    func testDebugCleanupRecordCodableRoundTrip_WithEntries() {
        let repl = DebugCleanupRecord.DictionaryReplacementEntry(key: "Dicticos", from: "Dicticos", to: "Dicticus")
        let block = DebugCleanupRecord.DictionaryBlockedEntry(key: "Gemini", from: "remind", to: "Gemini", ratio: 0.333)
        let steps = DebugCleanupRecord.Steps(
            raw: DebugCleanupRecord.StepEntry(text: "", ms: 0),
            post_dict: DebugCleanupRecord.StepEntry(text: "", ms: 0),
            post_itn: DebugCleanupRecord.StepEntry(text: "", ms: 0),
            post_swiss: DebugCleanupRecord.StepEntry(text: "", ms: 0),
            post_rules: DebugCleanupRecord.StepEntry(text: "", ms: 0),
            llm_prompt: nil,
            llm_raw: nil,
            post_gate: nil,
            post_swiss_num: DebugCleanupRecord.StepEntry(text: "", ms: 0)
        )
        let anomaly = DebugCleanupRecord.Anomaly(degenerate_collapse: false, very_short_output: false)
        let record = DebugCleanupRecord(
            ts: "2026-05-26T12:00:00.000Z",
            session_id: "test-session",
            lang: "en",
            lang_used: "en",
            mode: "plain",
            model: DebugCleanupRecord.ModelInfo(name: "test", sha256_prefix: nil),
            sampler: DebugCleanupRecord.SamplerInfo(temp: 0.1, top_k: 1, top_p: 1.0, max_tokens: 1, seed: nil),
            steps: steps,
            dictionary_context_keys: [],
            dictionary_replacements: [repl],
            dictionary_blocked: [block],
            anomaly: anomaly,
            emission_counter: 0
        )
        let data = try! JSONEncoder().encode(record)
        let roundtrip = try! JSONDecoder().decode(DebugCleanupRecord.self, from: data)
        XCTAssertEqual(roundtrip.dictionary_replacements.count, 1)
        XCTAssertEqual(roundtrip.dictionary_replacements[0].key, "Dicticos")
        XCTAssertEqual(roundtrip.dictionary_replacements[0].from, "Dicticos")
        XCTAssertEqual(roundtrip.dictionary_replacements[0].to, "Dicticus")
        XCTAssertEqual(roundtrip.dictionary_blocked.count, 1)
        XCTAssertEqual(roundtrip.dictionary_blocked[0].key, "Gemini")
        XCTAssertEqual(roundtrip.dictionary_blocked[0].from, "remind")
        XCTAssertEqual(roundtrip.dictionary_blocked[0].to, "Gemini")
        XCTAssertEqual(roundtrip.dictionary_blocked[0].ratio, 0.333, accuracy: 0.001)
    }
}
#endif
