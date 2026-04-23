import UIKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.dicticus.ios.keyboard", category: "keyboard")

class KeyboardViewController: UIInputViewController {
    private let dictationController = DicticusKeyboardDictationController()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDictationController()
        setupSwiftUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dictationController.setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dictationController.teardown()
    }

    // MARK: - Dictation Controller Wiring

    private func setupDictationController() {
        // Wire URL opening via responder chain (keyboard extensions cannot use UIApplication.shared.open)
        dictationController.openURL = { [weak self] url in
            self?.openURL(url)
        }

        // Wire transcription insertion via textDocumentProxy with smart text processing
        dictationController.onTranscriptionReady = { [weak self] text in
            guard let self else { return }
            let processedText = self.processTextForInsertion(text)
            self.textDocumentProxy.insertText(processedText)
            logger.info("Inserted transcription: \(processedText.prefix(50))")
        }
    }

    private func setupSwiftUI() {
        let keyboardView = KeyboardExtensionView(
            proxy: self.textDocumentProxy,
            advanceToNextInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            },
            dictationController: dictationController
        )

        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Responder Chain URL Opener

    /// Opens a URL from the keyboard extension using the responder chain.
    /// Keyboard extensions cannot use `UIApplication.shared.open()` -- this traverses
    /// the responder chain to find UIApplication and calls openURL on it.
    /// Uses the legacy `openURL:` selector which works in keyboard extensions.
    private func openURL(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                currentResponder.perform(selector, with: url)
                return
            }
            responder = currentResponder.next
        }
        logger.error("Failed to find responder for openURL")
    }

    // MARK: - Smart Text Insertion

    /// Processes transcription text for insertion: trims trailing newlines,
    /// normalizes leading capitalization based on cursor context,
    /// and adds smart leading space if needed.
    private func processTextForInsertion(_ text: String) -> String {
        // Step 0: Trim trailing newlines
        let cleaned = text.replacingOccurrences(of: #"[\r\n]+$"#, with: "", options: .regularExpression)
        guard !cleaned.isEmpty else { return cleaned }

        // Step 1: Capitalization normalization
        let contextBefore = textDocumentProxy.documentContextBeforeInput ?? ""
        var result = cleaned

        // If first character is uppercase and not at sentence start, lowercase it.
        // Preserves acronyms (e.g. "NASA") and proper nouns by checking if the second char is also uppercase.
        if let firstChar = result.first, firstChar.isUppercase {
            let isAcronymOrProperNoun = result.count >= 2 && result.dropFirst().first?.isUppercase == true
            if !isAcronymOrProperNoun {
                let trimmedContext = contextBefore.trimmingCharacters(in: .whitespaces)
                let atSentenceStart = trimmedContext.isEmpty ||
                    trimmedContext.hasSuffix(".") ||
                    trimmedContext.hasSuffix("!") ||
                    trimmedContext.hasSuffix("?") ||
                    trimmedContext.hasSuffix("\n")
                if !atSentenceStart {
                    result = result.prefix(1).lowercased() + result.dropFirst()
                }
            }
        }

        // Step 2: Smart leading space
        // Add a space before the transcription if the cursor is after a word/closing punctuation
        // and the transcription doesn't start with punctuation.
        if let lastChar = contextBefore.last {
            let needsSpace = lastChar.isLetter || lastChar.isNumber ||
                lastChar == ")" || lastChar == "]" || lastChar == "\"" ||
                lastChar == "\u{201D}" // right double quotation mark
            let startsWithPunctuation = result.first.map {
                ".!?,;:)]\"\u{201D}".contains($0)
            } ?? false

            if needsSpace && !startsWithPunctuation {
                result = " " + result
            }
        }

        return result
    }
}
