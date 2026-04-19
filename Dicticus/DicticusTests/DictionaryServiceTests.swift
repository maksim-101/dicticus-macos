import XCTest
@testable import Dicticus

@MainActor
final class DictionaryServiceTests: XCTestCase {
    
    var service: DictionaryService!
    
    override func setUp() {
        super.setUp()
        // Clear UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: DictionaryService.dictionaryKey)
        service = DictionaryService.shared
        service.removeAll() // Ensure clean state
    }
    
    func testPrepopulation() {
        // Force re-prepopulation by removing and re-initializing if possible, 
        // or just check if it's not empty after setup.
        // For testing we can just call prepopulate directly if it was public, 
        // but since it's private and called in init, we check the result.
        // We actually need a fresh instance to test init logic.
        // Since it's a singleton, we just verify it has some entries.
        XCTAssertFalse(service.dictionary.isEmpty)
        XCTAssertEqual(service.dictionary["true nest"], "TrueNAS")
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
        // "your" should NOT be replaced because it's not a separate word
        XCTAssertEqual(output, "how are thee today? your friend is here.")
    }
    
    func testPunctuationHandling() {
        service.setReplacement(for: "Swiss \"", with: "Swissquote")
        
        let input = "I use Swiss \""
        let output = service.apply(to: input)
        XCTAssertEqual(output, "I use Swissquote")
    }
    
    func testLengthPriority() {
        service.setReplacement(for: "cloth", with: "Something")
        service.setReplacement(for: "cloth desktop", with: "Claude Desktop")
        
        let input = "I use cloth desktop"
        let output = service.apply(to: input)
        // Should replace the longer one first
        XCTAssertEqual(output, "I use Claude Desktop")
    }
    
    func testAddAndRemove() {
        service.setReplacement(for: "test", with: "passed")
        XCTAssertEqual(service.dictionary["test"], "passed")
        
        service.removeReplacement(for: "test")
        XCTAssertNil(service.dictionary["test"])
    }
}
