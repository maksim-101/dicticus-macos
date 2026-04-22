import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUI()
    }
    
    private func setupSwiftUI() {
        let keyboardView = KeyboardExtensionView(
            proxy: self.textDocumentProxy,
            advanceToNextInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            },
            startDictation: {
                // To be implemented: bounce to main app
                print("Start dictation triggered")
            }
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
}
