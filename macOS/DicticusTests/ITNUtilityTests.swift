import XCTest
@testable import Dicticus

final class ITNUtilityTests: XCTestCase {

    // MARK: - Existing tests (must remain green)

    func testEnglishITN() {
        let input = "I have one hundred twenty three apples"
        let output = ITNUtility.applyITN(to: input, language: "en")
        XCTAssertEqual(output, "I have 123 apples")
    }

    func testEnglishHyphenatedITN() {
        let input = "The answer is forty-two"
        let output = ITNUtility.applyITN(to: input, language: "en")
        XCTAssertEqual(output, "The answer is 42")
    }

    func testGermanITN() {
        let input = "Ich habe einhundertdreiundzwanzig Äpfel"
        let output = ITNUtility.applyITN(to: input, language: "de")
        XCTAssertEqual(output, "Ich habe 123 Äpfel")
    }

    func testGermanComplexITN() {
        let input = "Das kostet viertausendfünfhundert Euro"
        let output = ITNUtility.applyITN(to: input, language: "de")
        XCTAssertEqual(output, "Das kostet 4500 Euro")
    }

    func testMixedText() {
        let input = "There are five birds and one cat"
        let output = ITNUtility.applyITN(to: input, language: "en")
        XCTAssertEqual(output, "There are five birds and one cat")
    }

    func testNoNumbers() {
        let input = "Hello world"
        let output = ITNUtility.applyITN(to: input, language: "en")
        XCTAssertEqual(output, "Hello world")
    }

    // MARK: - P0 regression tests (UAT record 134 — number concatenation bug)

    func testEnglishTwentyFiveNotConcatenated() {
        // NSNumberFormatter parsed "twenty five" (space) as 2005 because it tries
        // space-separated form first. Fix: try hyphenated form first.
        let output = ITNUtility.applyITN(to: "I have twenty five apples", language: "en")
        XCTAssertEqual(output, "I have 25 apples")
    }

    func testEnglishFortyOneNotConcatenated() {
        let output = ITNUtility.applyITN(to: "Page forty one", language: "en")
        XCTAssertEqual(output, "Page 41")
    }

    func testEnglishThirtySevenNotConcatenated() {
        let output = ITNUtility.applyITN(to: "thirty seven", language: "en")
        XCTAssertEqual(output, "37")
    }

    // MARK: - P3 structural word tests (numeric context conversion)

    func testEnglishPointBetweenDigits() {
        // "25 point 1" → "25.1"
        let output = ITNUtility.applyITN(to: "Version 25 point 1", language: "en")
        XCTAssertEqual(output, "Version 25.1")
    }

    func testEnglishDashBetweenDigits() {
        // "25 dash 06" → "25-06"
        let output = ITNUtility.applyITN(to: "25 dash 06", language: "en")
        XCTAssertEqual(output, "25-06")
    }

    func testEnglishHyphenBetweenDigits() {
        // "10 hyphen 3" → "10-3"
        let output = ITNUtility.applyITN(to: "10 hyphen 3", language: "en")
        XCTAssertEqual(output, "10-3")
    }

    func testEnglishPointAndDashVersionString() {
        // UAT record 134: "twenty five point one dash zero six" → "25.1-06"
        let output = ITNUtility.applyITN(to: "twenty five point one dash zero six", language: "en")
        XCTAssertEqual(output, "25.1-06")
    }

    func testGermanPunktBetweenDigits() {
        // "25 Punkt 1" → "25.1"
        let output = ITNUtility.applyITN(to: "25 Punkt 1", language: "de")
        XCTAssertEqual(output, "25.1")
    }

    func testGermanKommaBetweenDigits() {
        // "25 Komma 5" → "25,5"
        let output = ITNUtility.applyITN(to: "25 Komma 5", language: "de")
        XCTAssertEqual(output, "25,5")
    }

    func testEnglishPointNoFalsePositive() {
        // "the point is clear" — "point" NOT adjacent to digits, must not convert
        let output = ITNUtility.applyITN(to: "the point is clear", language: "en")
        XCTAssertEqual(output, "the point is clear")
    }

    func testGermanPunktNoFalsePositive() {
        // "Punkt eins" — left side has no digit, must not convert
        let output = ITNUtility.applyITN(to: "Punkt eins", language: "de")
        XCTAssertEqual(output, "Punkt eins")
    }

    func testEnglishZeroCollapseAfterDash() {
        // "1 dash zero 6" → "1-06"
        let output = ITNUtility.applyITN(to: "1 dash zero 6", language: "en")
        XCTAssertEqual(output, "1-06")
    }
}
