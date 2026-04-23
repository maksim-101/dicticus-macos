import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUI()
    }
    
    private var pollingTimer: Timer?
    
    private func setupSwiftUI() {
        let keyboardView = KeyboardExtensionView(
            proxy: self.textDocumentProxy,
            advanceToNextInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            },
            startDictation: { [weak self] in
                self?.handleDictationTap()
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
    
    private func handleDictationTap() {
        // 1. Set kbSource flag in shared UserDefaults
        let shared = UserDefaults(suiteName: "group.com.dicticus")
        shared?.set(true, forKey: "kbSource")
        
        // 2. Open main app via URL scheme
        // Note: Requires RequestsOpenAccess=YES in Info.plist
        let url = URL(string: "dicticus://dictate?source=keyboard")!
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            if success {
                // 3. Start polling for results
                self?.startPolling()
            }
        })
    }
    
    private func startPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForResult()
        }
    }
    
    private func checkForResult() {
        let shared = UserDefaults(suiteName: "group.com.dicticus")
        if shared?.bool(forKey: "kbResultReady") == true {
            if let result = shared?.string(forKey: "kbResult") {
                self.textDocumentProxy.insertText(result)
            }
            
            // Cleanup shared defaults
            shared?.set(false, forKey: "kbResultReady")
            shared?.removeObject(forKey: "kbResult")
            
            // Stop polling
            pollingTimer?.invalidate()
            pollingTimer = nil
        }
    }
}
