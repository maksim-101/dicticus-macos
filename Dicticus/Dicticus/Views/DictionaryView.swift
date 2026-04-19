import SwiftUI

/// A model representing a single replacement entry for the SwiftUI Table.
struct DictionaryEntry: Identifiable, Hashable {
    let id: String // Use the 'original' string as the unique ID
    var original: String
    var replacement: String
}

/// A window view for managing the custom dictionary find-replace pairs.
///
/// Per TEXT-02: Separate window with table/list for dictionary management.
struct DictionaryView: View {
    @EnvironmentObject var dictionaryService: DictionaryService
    @State private var entries: [DictionaryEntry] = []
    @State private var selection: Set<DictionaryEntry.ID> = []
    
    @State private var newOriginal: String = ""
    @State private var newReplacement: String = ""
    @State private var isShowingAddRow = false

    var body: some View {
        VStack(spacing: 0) {
            Table(entries, selection: $selection) {
                TableColumn("Original (ASR Error)") { entry in
                    Text(entry.original)
                }
                TableColumn("Replacement") { entry in
                    Text(entry.replacement)
                }
            }
            .contextMenu {
                Button("Delete") {
                    deleteSelected()
                }
                .disabled(selection.isEmpty)
            }

            Divider()

            HStack {
                if isShowingAddRow {
                    TextField("Original", text: $newOriginal)
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    TextField("Replacement", text: $newReplacement)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        addEntry()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newOriginal.isEmpty)

                    Button("Cancel") {
                        isShowingAddRow = false
                        newOriginal = ""
                        newReplacement = ""
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: { isShowingAddRow = true }) {
                        Label("Add Entry", systemImage: "plus")
                    }
                    
                    Spacer()
                    
                    Button("Delete Selected") {
                        deleteSelected()
                    }
                    .disabled(selection.isEmpty)
                    
                    Button("Remove All") {
                        dictionaryService.removeAll()
                        refreshEntries()
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 500, minHeight: 400)
        .navigationTitle("Custom Dictionary")
        .onAppear {
            refreshEntries()
        }
        .onChange(of: dictionaryService.dictionary) { _ in
            refreshEntries()
        }
    }

    private func refreshEntries() {
        entries = dictionaryService.dictionary.map { 
            DictionaryEntry(id: $0.key, original: $0.key, replacement: $0.value) 
        }.sorted { $0.original.lowercased() < $1.original.lowercased() }
    }

    private func addEntry() {
        dictionaryService.setReplacement(for: newOriginal, with: newReplacement)
        newOriginal = ""
        newReplacement = ""
        isShowingAddRow = false
        refreshEntries()
    }

    private func deleteSelected() {
        for id in selection {
            dictionaryService.removeReplacement(for: id)
        }
        selection.removeAll()
        refreshEntries()
    }
}

#Preview {
    DictionaryView()
        .environmentObject(DictionaryService.shared)
}
