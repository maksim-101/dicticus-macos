import SwiftUI

struct DictionaryManagementView: View {
    @EnvironmentObject var dictionaryService: DictionaryService
    @State private var showingAddSheet = false
    @State private var newOriginal = ""
    @State private var newReplacement = ""
    @State private var sortOrder: EntrySortOrder = .alphabetical
    
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
                        .disabled(newOriginal.isEmpty || newReplacement.isEmpty)
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
    }
}

#Preview {
    NavigationStack {
        DictionaryManagementView()
            .environmentObject(DictionaryService.shared)
    }
}
