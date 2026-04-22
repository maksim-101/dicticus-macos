import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var warmupService: IOSModelWarmupService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Integration") {
                    NavigationLink(destination: SetupGuidesView()) {
                        Label("Setup Guides", systemImage: "questionmark.circle")
                    }
                    
                    Button(action: openSystemSettings) {
                        Label("System Permissions", systemImage: "gear")
                    }
                }
                
                Section("Transcriptions") {
                    NavigationLink(destination: DictionaryManagementView()) {
                        Label("Custom Dictionary", systemImage: "book")
                    }
                    
                    Toggle(isOn: .init(get: {
                        UserDefaults.standard.bool(forKey: "useCustomDictionary") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("useCustomDictionary")
                    }, set: { 
                        UserDefaults.standard.set($0, forKey: "useCustomDictionary")
                    })) {
                        Label("Apply Replacements", systemImage: "character.cursor.ibeam")
                    }
                    
                    Toggle(isOn: .init(get: {
                        UserDefaults.standard.bool(forKey: "useITN") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("useITN")
                    }, set: { 
                        UserDefaults.standard.set($0, forKey: "useITN")
                    })) {
                        Label("Numbers to Digits", systemImage: "number")
                    }
                }
                
                Section("Model Management") {
                    HStack {
                        Label("ASR Model (Parakeet)", systemImage: "cpu")
                        Spacer()
                        if warmupService.hasModels {
                            Text("Ready").foregroundColor(.green)
                        } else {
                            Text("Missing").foregroundColor(.red)
                        }
                    }
                    
                    Button(role: .destructive, action: { warmupService.warmup() }) {
                        Label("Force Model Update", systemImage: "arrow.clockwise")
                    }
                    .disabled(warmupService.isWarming)
                }
                
                Section {
                    Link(destination: URL(string: "https://github.com/maksim-101/dicticus")!) {
                        Label("Source Code", systemImage: "link")
                    }
                } header: {
                    Text("About")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dicticus v1.0")
                        Text("\u{00A9} 2026 Maksim-101")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(IOSModelWarmupService())
}
