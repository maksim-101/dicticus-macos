import XCTest
@testable import Dicticus

final class ITNUtilityTests: XCTestCase {
    
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
        XCTAssertEqual(output, "There are 5 birds and 1 cat")
    }
    
    func testNoNumbers() {
        let input = "Hello world"
        let output = ITNUtility.applyITN(to: input, language: "en")
        XCTAssertEqual(output, "Hello world")
    }
}
