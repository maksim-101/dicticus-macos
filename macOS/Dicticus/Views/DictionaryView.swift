import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// A model representing a single replacement entry for the SwiftUI Table.
struct DictionaryEntry: Identifiable, Hashable {
    let id: String // Use the 'original' string as the unique ID
    var original: String
    var replacement: String
    var createdAt: Date
}

enum DictionarySortMode: String, CaseIterable, Identifiable {
    case alphabetical = "A-Z"
    case mostRecent = "Recent"
    
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .alphabetical: return "A-Z"
        case .mostRecent: return "Recent"
        }
    }
}

/// A window view for managing the custom dictionary find-replace pairs.
struct DictionaryView: View {
    @EnvironmentObject var dictionaryService: DictionaryService
    @State private var entries: [DictionaryEntry] = []
    @State private var selection: Set<DictionaryEntry.ID> = []
    
    @State private var sortMode: DictionarySortMode = .mostRecent
    @State private var isShowingRemoveAllConfirmation = false
    @State private var duplicateWarning: String? = nil
    
    @State private var newOriginal: String = ""
    @State private var newReplacement: String = ""
    @State private var isShowingAddRow = false

    // Import / Export state (Phase 31-02)
    @State private var importResult: String? = nil
    @State private var isShowingImportResult = false
    @State private var pendingImportURL: URL? = nil
    @State private var isShowingMergeStrategyPicker = false

    // Starter pack state (Phase 31-03)
    @State private var starterPackResult: String? = nil
    @State private var isShowingStarterPackResult = false
    @State private var importedPacks: Set<DictionaryService.StarterPack> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header / Toolbar
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text("Case Sensitive")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                    Toggle("", isOn: $dictionaryService.isCaseSensitive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.6) // Smaller scale to match button heights and reduce border thickness
                        .frame(width: 32, height: 20)
                }
                .padding(.leading, 16)

                Spacer()

                Text("\(dictionaryService.dictionary.count) \(dictionaryService.dictionary.count == 1 ? "entry" : "entries")")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("", selection: $sortMode) {
                    ForEach(DictionarySortMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .controlSize(.regular)
                .padding(.trailing, 16)
            }
            .frame(height: 50)
            .background(.ultraThinMaterial)

            Divider()

            // Main Table
            Table(entries, selection: $selection) {
                TableColumn("Original (ASR Error)") { entry in
                    Text(entry.original)
                        .font(.system(size: 13))
                }
                TableColumn("Replacement") { entry in
                    Text(entry.replacement)
                        .font(.system(size: 13))
                }
            }
            .tableStyle(.inset)
            .contextMenu {
                Button("Delete") {
                    deleteSelected()
                }
                .disabled(selection.isEmpty)
            }

            // Duplicate Warning
            if let warning = duplicateWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(warning)
                }
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .padding(.vertical, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()

            // Footer / Actions
            HStack(spacing: 12) {
                if isShowingAddRow {
                    HStack(spacing: 8) {
                        TextField("Original error", text: $newOriginal)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.regular)
                            .font(.system(size: 13))
                            .onChange(of: newOriginal) { _, newValue in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    checkForDuplicate(newValue)
                                }
                            }
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Replacement", text: $newReplacement)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.regular)
                            .font(.system(size: 13))
                        
                        Button("Add") {
                            addEntry()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(newOriginal.isEmpty || duplicateWarning != nil)

                        Button("Cancel") {
                            cancelAdd()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                } else {
                    Button(action: { 
                        withAnimation(.spring(response: 0.3)) {
                            isShowingAddRow = true 
                        }
                    }) {
                        Label("Add Entry", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Spacer()
                    
                    Button("Delete Selected") {
                        deleteSelected()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(selection.isEmpty)

                    Button("Remove All") {
                        isShowingRemoveAllConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .foregroundStyle(.red)

                    Divider()
                        .frame(height: 20)

                    Menu {
                        Button("Export as CSV") { exportDictionary(format: "csv") }
                        Button("Export as JSON") { exportDictionary(format: "json") }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(action: { showImportPanel() }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            // Starter Packs (Phase 31-03)
            VStack(alignment: .leading, spacing: 8) {
                Text("Starter Packs")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(DictionaryService.StarterPack.allCases, id: \.self) { pack in
                        let imported = importedPacks.contains(pack)
                        Button(action: { importStarterPack(pack) }) {
                            Label(pack.displayTitle, systemImage: imported ? "checkmark.circle.fill" : "tray.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(imported ? .green : nil)
                        .help(imported ? "All entries from this pack are already in your dictionary" : "Import this pack")
                    }
                }

                Text("The dictionary starts empty by design so no personal data ships in the public app. Grow it three ways: add entries manually above, tap a starter pack to import curated corrections in one click, or import a CSV file. You can also ask an AI (ChatGPT, Claude, etc.) to generate a CSV for your field — e.g. \"Give me 50 common medical dictation mishearings as original,replacement CSV\" — then import it here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            // Spoken Punctuation Reference (Phase 32 D-07)
            VStack(alignment: .leading, spacing: 8) {
                Text("Spoken Punctuation")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Always")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        LabeledContent("hyphen / Bindestrich", value: "-")
                        LabeledContent("slash / Schrägstrich", value: "/")
                        LabeledContent("backslash", value: "\\")
                        LabeledContent("underscore / Unterstrich", value: "_")
                        LabeledContent("asterisk / Sternchen", value: "*")
                        LabeledContent("semicolon", value: ";")
                        LabeledContent("at sign / Klammeraffe", value: "@")
                        LabeledContent("hash / Raute", value: "#")
                        LabeledContent("caret", value: "^")
                        LabeledContent("tilde", value: "~")
                    }
                    .font(.system(size: 12))
                }

                Text("Between identifier words")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("minus", value: "-")
                    LabeledContent("dot", value: ".")
                    LabeledContent("colon", value: ":")
                    LabeledContent("dollar", value: "$")
                }
                .font(.system(size: 12))

                Text("Conditional symbols collapse only when flanked by identifier-shaped words (e.g. \"Claude minus ops\" → \"Claude-ops\"). \"dot\" also collapses between number-words (\"ten dot five\" → \"10.5\").")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 550, minHeight: 450)
        .navigationTitle("Custom Dictionary")
        .alert("Remove All Entries?", isPresented: $isShowingRemoveAllConfirmation) {
            Button("Remove All", role: .destructive) {
                dictionaryService.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all dictionary entries? This cannot be undone.")
        }
        .onAppear {
            refreshEntries()
        }
        .onChange(of: dictionaryService.dictionary) { _, _ in
            refreshEntries()
        }
        .onChange(of: sortMode) { _, _ in
            refreshEntries()
        }
        .alert("Import Result", isPresented: $isShowingImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResult ?? "")
        }
        .alert("Starter Pack Imported", isPresented: $isShowingStarterPackResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(starterPackResult ?? "")
        }
        .confirmationDialog("Choose Merge Strategy", isPresented: $isShowingMergeStrategyPicker, titleVisibility: .visible) {
            Button("Replace All (delete current, then import)") {
                if let url = pendingImportURL { performImport(url: url, strategy: .replaceAll) }
            }
            Button("Merge — keep mine on conflicts") {
                if let url = pendingImportURL { performImport(url: url, strategy: .existingWins) }
            }
            Button("Merge — use imported on conflicts") {
                if let url = pendingImportURL { performImport(url: url, strategy: .incomingWins) }
            }
            Button("Cancel", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("You have \(dictionaryService.dictionary.count) entries. Choose how to combine them with the imported file. \"Conflicts\" are entries whose Original appears in both.")
        }
    }

    private func refreshEntries() {
        let mapped = dictionaryService.dictionary.map { 
            DictionaryEntry(id: $0.key, original: $0.key, replacement: $0.value.replacement, createdAt: $0.value.createdAt) 
        }
        
        switch sortMode {
        case .alphabetical:
            entries = mapped.sorted { $0.original.lowercased() < $1.original.lowercased() }
        case .mostRecent:
            entries = mapped.sorted { $0.createdAt > $1.createdAt }
        }

        importedPacks = Set(DictionaryService.StarterPack.allCases.filter { dictionaryService.isStarterPackImported($0) })
    }

    private func checkForDuplicate(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if dictionaryService.dictionary.keys.contains(trimmed) {
            duplicateWarning = "Entry '\(trimmed)' already exists."
        } else {
            duplicateWarning = nil
        }
    }

    private func addEntry() {
        dictionaryService.setReplacement(for: newOriginal, with: newReplacement)
        newOriginal = ""
        newReplacement = ""
        isShowingAddRow = false
        duplicateWarning = nil
        refreshEntries()
    }

    private func cancelAdd() {
        isShowingAddRow = false
        newOriginal = ""
        newReplacement = ""
        duplicateWarning = nil
    }

    private func deleteSelected() {
        for id in selection {
            dictionaryService.removeReplacement(for: id)
        }
        selection.removeAll()
        refreshEntries()
    }

    // MARK: - Starter Packs (Phase 31-03)

    private func importStarterPack(_ pack: DictionaryService.StarterPack) {
        let result = dictionaryService.importStarterPack(pack)
        starterPackResult = result.summaryMessage(source: pack.displayTitle)
        isShowingStarterPackResult = true
    }

    // MARK: - Import / Export (Phase 31-02)

    private func exportDictionary(format: String) {
        let data = dictionaryService.exportData(format: format)
        let ext = format.lowercased()
        let panel = NSSavePanel()
        panel.allowedContentTypes = ext == "json" ? [.json] : [.commaSeparatedText]
        let dateStamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        panel.nameFieldStringValue = "Dicticus-dictionary-\(dateStamp).\(ext)"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func showImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            pendingImportURL = url
            // Nothing to conflict with on an empty dictionary — skip the merge prompt.
            if dictionaryService.dictionary.isEmpty {
                performImport(url: url, strategy: .incomingWins)
            } else {
                isShowingMergeStrategyPicker = true
            }
        }
    }

    private func performImport(url: URL, strategy: MergeStrategy) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            importResult = "Could not read file."
            isShowingImportResult = true
            return
        }
        let format = url.pathExtension.lowercased()
        let result = dictionaryService.importData(data, format: format, strategy: strategy)
        importResult = result.summaryMessage()
        isShowingImportResult = true
        pendingImportURL = nil
    }
}
