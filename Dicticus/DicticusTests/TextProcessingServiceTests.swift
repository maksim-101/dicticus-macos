import XCTest
@testable import Dicticus

@MainActor
final class TextProcessingServiceTests: XCTestCase {
    
    var service: TextProcessingService!
    var dictionaryService: DictionaryService!
    
    override func setUp() {
        super.setUp()
        // Use a fresh dictionary service for isolation
        UserDefaults.standard.removeObject(forKey: DictionaryService.dictionaryKey)
        dictionaryService = DictionaryService.shared
        dictionaryService.removeAll()
        service = TextProcessingService(dictionaryService: dictionaryService, cleanupService: nil)
    }
    
    func testPipelineOrder() async {
        // 1. Set up dictionary: "bird" -> "one hundred"
        dictionaryService.setReplacement(for: "bird", with: "one hundred")
        
        let input = "I have a bird"
        // Expected: "I have a bird" -> "I have a one hundred" (Dictionary) -> "I have a 100" (ITN)
        let output = await service.process(text: input, language: "en", mode: .plain)
        
        XCTAssertEqual(output, "I have a 100")
    }
    
    func testGermanPipeline() async {
        dictionaryService.setReplacement(for: "Apfel", with: "einhundert")
        
        let input = "Ich habe einen Apfel"
        // Expected: "Ich habe einen Apfel" -> "Ich habe einen einhundert" -> "Ich habe einen 100"
        let output = await service.process(text: input, language: "de", mode: .plain)
        
        XCTAssertEqual(output, "Ich habe einen 100")
    }
}
