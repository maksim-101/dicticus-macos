import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper for .fileExporter (Phase 31-02).
struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json, .plainText] }
    var text: String
    init(_ text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct DictionaryManagementView: View {
    @EnvironmentObject var dictionaryService: DictionaryService
    @State private var showingAddSheet = false
    @State private var newOriginal = ""
    @State private var newReplacement = ""
    @State private var duplicateWarning: String? = nil
    @State private var sortOrder: EntrySortOrder = .alphabetical

    // Import / Export state (Phase 31-02)
    @State private var showingExporter = false
    @State private var exportFormat = "csv"
    @State private var showingImporter = false
    @State private var showingMergeStrategyPicker = false
    @State private var pendingImportData: Data? = nil
    @State private var pendingImportFormat: String = "csv"
    @State private var importResultMessage: String? = nil
    @State private var showingImportResult = false

    // Starter packs state (Phase 31-03)
    @State private var starterPackResultMessage: String? = nil
    @State private var showingStarterPackResult = false
    
    enum EntrySortOrder {
        case alphabetical, mostRecent
    }
    
    private var sortedKeys: [String] {
        switch sortOrder {
        case .alphabetical:
            return dictionaryService.dictionary.keys.sorted()
        case .mostRecent:
            return dictionaryService.dictionary.keys.sorted {
                (dictionaryService.dictionary[$0]?.createdAt ?? Date.distantPast) >
                (dictionaryService.dictionary[$1]?.createdAt ?? Date.distantPast)
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                Toggle("Case Sensitive Matching", isOn: $dictionaryService.isCaseSensitive)
            } footer: {
                Text("When enabled, 'truenas' will not match 'TrueNAS'.")
            }
            
            Section("Import / Export") {
                Menu {
                    Button("Export as CSV") {
                        exportFormat = "csv"
                        showingExporter = true
                    }
                    Button("Export as JSON") {
                        exportFormat = "json"
                        showingExporter = true
                    }
                } label: {
                    Label("Export Dictionary", systemImage: "square.and.arrow.up")
                }

                Button(action: { showingImporter = true }) {
                    Label("Import Dictionary", systemImage: "square.and.arrow.down")
                }
            }

            Section {
                ForEach(DictionaryService.StarterPack.allCases, id: \.self) { pack in
                    Button(action: { importStarterPack(pack) }) {
                        Label(pack.displayTitle, systemImage: "tray.and.arrow.down")
                    }
                }
            } header: {
                Text("Starter Packs")
            } footer: {
                Text("The dictionary starts empty by design — no personal data ships in the app. Grow it three ways: add entries manually, tap a starter pack to import curated corrections in one click, or import a CSV file.\n\nTip: ask an AI (ChatGPT, Claude, etc.) to generate a CSV for your field — e.g. \"Give me 50 common medical dictation mishearings as original,replacement CSV\" — then tap Import.")
            }

            Section("Custom Replacements") {
                if dictionaryService.dictionary.isEmpty {
                    Text("No custom entries yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedKeys, id: \.self) { key in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(key)
                                    .font(.headline)
                                Text(dictionaryService.dictionary[key]?.replacement ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(key) replaced with \(dictionaryService.dictionary[key]?.replacement ?? "")")
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
        }
        .navigationTitle("Dictionary")
        .fileExporter(
            isPresented: $showingExporter,
            document: PlainTextDocument(exportedText()),
            contentType: exportFormat == "json" ? .json : .commaSeparatedText,
            defaultFilename: "Dicticus-dictionary-\(dateStamp()).\(exportFormat)"
        ) { _ in }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .json],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            let format = url.pathExtension.lowercased()
            // Store data before closure exits — URL scope ends here (Pitfall 4).
            pendingImportData = data
            pendingImportFormat = format.isEmpty ? "csv" : format
            showingMergeStrategyPicker = true
        }
        .confirmationDialog("Choose Merge Strategy", isPresented: $showingMergeStrategyPicker, titleVisibility: .visible) {
            Button("Replace All (clears existing)") { applyImport(strategy: .replaceAll) }
            Button("Keep Existing (skip conflicts)") { applyImport(strategy: .existingWins) }
            Button("Use Incoming (overwrite conflicts)") { applyImport(strategy: .incomingWins) }
            Button("Cancel", role: .cancel) { pendingImportData = nil }
        }
        .alert("Import Result", isPresented: $showingImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage ?? "")
        }
        .alert("Starter Pack Imported", isPresented: $showingStarterPackResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(starterPackResultMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        Label("Alphabetical", systemImage: "textformat.abc").tag(EntrySortOrder.alphabetical)
                        Label("Most Recent", systemImage: "clock").tag(EntrySortOrder.mostRecent)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort order")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    Section("Original Phrase") {
                        TextField("e.g. true nest", text: $newOriginal)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: newOriginal) { _, newValue in
                                checkForDuplicate(newValue)
                            }
                    } footer: {
                        if let warning = duplicateWarning {
                            Text(warning)
                                .foregroundColor(.orange)
                        }
                    }
                    Section("Replacement") {
                        TextField("e.g. TrueNAS", text: $newReplacement)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle("Add Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddSheet = false
                            resetFields()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            dictionaryService.setReplacement(for: newOriginal, with: newReplacement)
                            showingAddSheet = false
                            resetFields()
                        }
                        .disabled(newOriginal.isEmpty || newReplacement.isEmpty || duplicateWarning != nil)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        let currentKeys = sortedKeys
        for index in offsets {
            dictionaryService.removeReplacement(for: currentKeys[index])
        }
    }
    
    private func resetFields() {
        newOriginal = ""
        newReplacement = ""
        duplicateWarning = nil
    }

    private func checkForDuplicate(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if dictionaryService.dictionary.keys.contains(trimmed) {
            duplicateWarning = "Entry '\(trimmed)' already exists."
        } else {
            duplicateWarning = nil
        }
    }

    // MARK: - Starter Packs (Phase 31-03)

    private func importStarterPack(_ pack: DictionaryService.StarterPack) {
        let result = dictionaryService.importStarterPack(pack)
        switch result {
        case .success(let added, let warnings):
            var msg = "Imported \(added) entries from \(pack.displayTitle)."
            if !warnings.isEmpty {
                msg += "\n\nWarnings:\n" + warnings.joined(separator: "\n")
            }
            starterPackResultMessage = msg
        case .failure(let error):
            starterPackResultMessage = "Import failed: \(error)"
        }
        showingStarterPackResult = true
    }

    // MARK: - Import / Export helpers (Phase 31-02)

    private func exportedText() -> String {
        let data = dictionaryService.exportData(format: exportFormat)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func dateStamp() -> String {
        String(ISO8601DateFormatter().string(from: Date()).prefix(10))
    }

    private func applyImport(strategy: MergeStrategy) {
        guard let data = pendingImportData else { return }
        let result = dictionaryService.importData(data, format: pendingImportFormat, strategy: strategy)
        switch result {
        case .success(let added, let warnings):
            var msg = "Imported \(added) entries."
            if !warnings.isEmpty {
                msg += "\n\nWarnings:\n" + warnings.joined(separator: "\n")
            }
            importResultMessage = msg
        case .failure(let error):
            importResultMessage = "Import failed: \(error)"
        }
        showingImportResult = true
        pendingImportData = nil
    }
}

#Preview {
    NavigationStack {
        DictionaryManagementView()
            .environmentObject(DictionaryService.shared)
    }
}
