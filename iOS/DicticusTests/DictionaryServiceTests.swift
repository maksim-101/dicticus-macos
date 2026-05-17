import XCTest
@testable import Dicticus

@MainActor
final class DictionaryServiceTests: XCTestCase {

    var service: DictionaryService!

    override func setUp() {
        super.setUp()
        service = DictionaryService.shared
        service.removeAll()
        service.isCaseSensitive = false
    }

    func testCaseInsensitiveReplacement() {
        service.setReplacement(for: "cloud", with: "Claude")
        let input = "I love the CLOUD"
        let output = service.apply(to: input)
        XCTAssertEqual(output, "I love the Claude")
    }

    func testWordBoundaryReplacement() {
        service.setReplacement(for: "you", with: "thee")
        let input = "how are you today? your friend is here."
        let output = service.apply(to: input)
        XCTAssertEqual(output, "how are thee today? your friend is here.")
    }

    func testAddAndRemove() {
        service.setReplacement(for: "test", with: "passed")
        XCTAssertEqual(service.dictionary["test"]?.replacement, "passed")
        service.removeReplacement(for: "test")
        XCTAssertNil(service.dictionary["test"])
    }
}

// MARK: - Phase 25.1-03: Class B entries (paper §2.2 lexical priming)
//
// Each test locks a real 25-03 live-capture failure from
// .planning/phases/25-…/25-03-v16-prompt-and-dictionary-feeder-SUMMARY.md
// Class B section. Tests use setReplacement to seed entries because
// prepopulateWithDefaults is private and setUp calls removeAll.
// Both the dictionary-state path and apply(to:) runtime path are verified.

@MainActor
final class DictionaryServiceClassBTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let s = DictionaryService.shared
        s.removeAll()
        // Seed the Phase 25.1-03 Class B entries (mirrors prepopulateWithDefaults)
        s.setReplacement(for: "Chema 4 2EB", with: "Gemma 4 E2B")
        s.setReplacement(for: "chema 4 2eb", with: "Gemma 4 E2B")
        s.setReplacement(for: "Dicticos", with: "Dicticus")
        s.setReplacement(for: "dicticos", with: "Dicticus")
        s.setReplacement(for: "Olama", with: "Ollama")
        s.setReplacement(for: "olama", with: "Ollama")
        s.setReplacement(for: "Tailskill", with: "Tailscale")
        s.setReplacement(for: "tailskill", with: "Tailscale")
        s.setReplacement(for: "hopath", with: "homeopath")
    }

    func testPhase251_ClassB_Chema4_2EB_2026_05_17T06_02_10() {
        XCTAssertEqual(DictionaryService.shared.dictionary["Chema 4 2EB"]?.replacement, "Gemma 4 E2B")
        let out = DictionaryService.shared.apply(to: "I am using Chema 4 2EB for cleanup.")
        XCTAssertTrue(out.contains("Gemma 4 E2B"), "Got: \(out)")
    }

    func testPhase251_ClassB_Tailskill_2026_05_17T05_30_23() {
        let out = DictionaryService.shared.apply(to: "open the Tailskill dashboard")
        XCTAssertEqual(out, "open the Tailscale dashboard")
    }

    func testPhase251_ClassB_Dicticos() {
        let out = DictionaryService.shared.apply(to: "this is Dicticos working")
        XCTAssertEqual(out, "this is Dicticus working")
    }

    func testPhase251_ClassB_Olama() {
        let out = DictionaryService.shared.apply(to: "I switched from Olama to llama.cpp")
        XCTAssertEqual(out, "I switched from Ollama to llama.cpp")
    }

    func testPhase251_ClassB_hopath() {
        let out = DictionaryService.shared.apply(to: "the hopath consultation went well")
        XCTAssertEqual(out, "the homeopath consultation went well")
    }

    func testPhase251_ClassB_LowercaseVariantsExist() {
        // ASR can emit either case; verify both keys map to the same target.
        XCTAssertEqual(DictionaryService.shared.dictionary["chema 4 2eb"]?.replacement, "Gemma 4 E2B")
        XCTAssertEqual(DictionaryService.shared.dictionary["dicticos"]?.replacement, "Dicticus")
        XCTAssertEqual(DictionaryService.shared.dictionary["olama"]?.replacement, "Ollama")
        XCTAssertEqual(DictionaryService.shared.dictionary["tailskill"]?.replacement, "Tailscale")
    }
}

// MARK: - Phase 25.1-03: fuzzy match (Levenshtein ≤ 2, length ≥ 6)

@MainActor
final class DictionaryServiceFuzzyMatchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let s = DictionaryService.shared
        s.removeAll()
        s.setReplacement(for: "Tailscale", with: "Tailscale")
        s.setReplacement(for: "tailskill", with: "Tailscale")
        s.setReplacement(for: "Tailskill", with: "Tailscale")
        s.setReplacement(for: "Ollama", with: "Ollama")
        s.setReplacement(for: "Olama", with: "Ollama")
        s.isCaseSensitive = false
    }

    func testPhase251_FuzzyMatch_TailskillVariants() {
        // "Tailskil" (distance 1 from "tailskill") — fuzzy catches it
        let out1 = DictionaryService.shared.apply(to: "open the Tailskil dashboard")
        XCTAssertEqual(out1, "open the Tailscale dashboard")
        // "Tailscele" (distance 2 from "Tailscale" key) — fuzzy catches it
        let out2 = DictionaryService.shared.apply(to: "open the Tailscele dashboard")
        XCTAssertEqual(out2, "open the Tailscale dashboard")
    }

    func testPhase251_FuzzyMatch_DoesNotFireOnShortTokens() {
        // Short tokens (< 6 chars) must never fuzzy-match even at distance ≤ 2.
        let out = DictionaryService.shared.apply(to: "the man went home")
        XCTAssertEqual(out, "the man went home", "Short tokens (< 6 chars) must be ineligible for fuzzy match")
    }

    func testPhase251_FuzzyMatch_ExactMatchWinsOverFuzzy() {
        // Exact match runs first; verify result is correct and no double-edit.
        let out = DictionaryService.shared.apply(to: "Olama is great")
        XCTAssertEqual(out, "Ollama is great")
    }

    func testPhase251_FuzzyMatch_LengthDeltaCap() {
        // Tokens whose length differs from a key by > 2 must NOT fuzzy-match.
        DictionaryService.shared.setReplacement(for: "abcdefgh", with: "XYZ")
        let out = DictionaryService.shared.apply(to: "the word here is abc")
        XCTAssertFalse(out.contains("XYZ"), "Length delta > 2 must skip fuzzy match")
        DictionaryService.shared.removeReplacement(for: "abcdefgh")
    }

    func testPhase251_FuzzyMatch_MultiWordKeysSkipped() {
        // Multi-word keys are only matched by the exact-match regex path, never fuzzy.
        DictionaryService.shared.setReplacement(for: "engine eggs", with: "NGINX")
        let out = DictionaryService.shared.apply(to: "use engine for builds")
        XCTAssertEqual(out, "use engine for builds", "Single-token input must not fuzzy-match multi-word key")
    }

    func testPhase251_FuzzyMatch_PerformanceBudget() {
        // 2KB input, seeded dictionary. Fuzzy pass must complete < 50ms.
        let longInput = String(repeating: "Tailskill dashboard config and tools ", count: 60)
        let start = Date()
        _ = DictionaryService.shared.apply(to: longInput)
        let elapsedMs = Date().timeIntervalSince(start) * 1000
        XCTAssertLessThan(elapsedMs, 50.0, "apply(to:) on 2KB input must complete < 50ms (got \(elapsedMs)ms)")
    }
}
