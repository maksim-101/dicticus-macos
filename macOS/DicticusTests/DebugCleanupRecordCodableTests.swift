import XCTest
@testable import Dicticus

#if DEBUG_RECORDER

final class DebugCleanupRecordCodableTests: XCTestCase {

    // MARK: - Helpers

    private func makeMinimalRecord(promptVersion: String = "v19d") -> DebugCleanupRecord {
        DebugCleanupRecord(
            ts: "2026-05-27T05:00:00.000Z",
            session_id: "test-session",
            lang: "en",
            lang_used: "en",
            mode: "cleanup",
            model: .init(name: "gemma-4-e2b", sha256_prefix: nil),
            sampler: .init(temp: 0.1, top_k: 40, top_p: 0.9, max_tokens: 512, seed: nil),
            steps: .init(
                raw: .init(text: "hello", ms: 0),
                post_dict: .init(text: "hello", ms: 1),
                post_itn: .init(text: "hello", ms: 1),
                post_swiss: .init(text: "hello", ms: 0),
                post_rules: .init(text: "hello", ms: 0),
                llm_prompt: nil,
                llm_raw: nil,
                post_gate: nil,
                post_swiss_num: .init(text: "hello", ms: 0)
            ),
            dictionary_context_keys: [],
            dictionary_replacements: [],
            dictionary_blocked: [],
            anomaly: .init(degenerate_collapse: false, very_short_output: false),
            emission_counter: 1,
            prompt_version: promptVersion
        )
    }

    // MARK: - Phase 27 WR-02 baseline (existing)

    func testDebugCleanupRecordCodableRoundTrip_DefaultEmpty() {
        // Regression guard: basic round-trip with empty arrays for Phase-27 fields.
        let rec = makeMinimalRecord()
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(rec) else {
            XCTFail("Encoding failed")
            return
        }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(DebugCleanupRecord.self, from: data) else {
            XCTFail("Decoding failed")
            return
        }
        XCTAssertEqual(decoded.dictionary_replacements.count, 0)
        XCTAssertEqual(decoded.dictionary_blocked.count, 0)
    }

    // MARK: - Phase 28 R3: prompt_version round-trip tests

    func testDebugCleanupRecordCodableRoundTrip_PromptVersionDefault_v19d() {
        // Construct with default prompt_version; encode; decode; assert "v19d".
        let rec = makeMinimalRecord()
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(rec) else {
            XCTFail("Encoding failed")
            return
        }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(DebugCleanupRecord.self, from: data) else {
            XCTFail("Decoding failed")
            return
        }
        XCTAssertEqual(decoded.prompt_version, "v19d", "Default prompt_version must round-trip as 'v19d' (Phase 28 R3)")
    }

    func testDebugCleanupRecordCodableRoundTrip_ExplicitPromptVersion_v19c() {
        // Construct with explicit prompt_version "v19c"; encode; decode; assert "v19c".
        let rec = makeMinimalRecord(promptVersion: "v19c")
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(rec) else {
            XCTFail("Encoding failed")
            return
        }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(DebugCleanupRecord.self, from: data) else {
            XCTFail("Decoding failed")
            return
        }
        XCTAssertEqual(decoded.prompt_version, "v19c", "Explicit prompt_version 'v19c' must round-trip correctly (Phase 28 R3)")
    }

    func testDebugCleanupRecordDecode_TolerantToMissingPromptVersion() {
        // Hand-craft a JSON dict matching pre-Phase-28 schema (no prompt_version key).
        // Decode via JSONDecoder; assert decoded.prompt_version == "v19c" (decodeIfPresent default).
        let jsonString = """
        {
            "ts": "2026-05-25T04:00:00.000Z",
            "session_id": "legacy-session",
            "lang": "en",
            "lang_used": "en",
            "mode": "cleanup",
            "model": {"name": "gemma-4-e2b", "sha256_prefix": null},
            "sampler": {"temp": 0.1, "top_k": 40, "top_p": 0.9, "max_tokens": 512, "seed": null},
            "steps": {
                "raw": {"text": "test", "ms": 0},
                "post_dict": {"text": "test", "ms": 0},
                "post_itn": {"text": "test", "ms": 0},
                "post_swiss": {"text": "test", "ms": 0},
                "post_rules": {"text": "test", "ms": 0},
                "llm_prompt": null,
                "llm_raw": null,
                "post_gate": null,
                "post_swiss_num": {"text": "test", "ms": 0}
            },
            "dictionary_context_keys": [],
            "dictionary_replacements": [],
            "dictionary_blocked": [],
            "anomaly": {"degenerate_collapse": false, "very_short_output": false},
            "emission_counter": 1
        }
        """
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to create JSON data")
            return
        }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(DebugCleanupRecord.self, from: data) else {
            XCTFail("Decoding pre-Phase-28 JSONL (no prompt_version key) must succeed (Phase 28 R3 backward-compat / WR-02 pattern)")
            return
        }
        XCTAssertEqual(decoded.prompt_version, "v19c",
                       "Missing prompt_version key must decode as 'v19c' (Phase 28 R3 decodeIfPresent default, mirrors Phase 27 WR-02 pattern)")
    }
}

#endif
