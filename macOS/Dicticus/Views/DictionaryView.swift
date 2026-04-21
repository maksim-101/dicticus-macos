import SwiftUI

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
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    }

    private func checkForDuplicate(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if dictionaryService.dictionary.keys.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
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
}
