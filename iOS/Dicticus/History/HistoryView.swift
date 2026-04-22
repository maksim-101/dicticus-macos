import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyService: HistoryService
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                if historyService.entries.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text("Your transcriptions will appear here.")
                    )
                } else {
                    ForEach(historyService.entries) { entry in
                        HistoryRow(entry: entry)
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search transcriptions")
            .onChange(of: searchText) { _, newValue in
                historyService.load(query: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            if let id = historyService.entries[index].id {
                historyService.delete(id: id)
            }
        }
    }
}

struct HistoryRow: View {
    let entry: TranscriptionEntry
    @State private var showingCopiedMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.language.uppercased())
                    .font(.caption2).bold()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Text(entry.text)
                .font(.body)
                .lineLimit(3)
            
            HStack {
                Label("\(Int(entry.confidence * 100))%", systemImage: "waveform")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    Label(showingCopiedMessage ? "Copied" : "Copy", systemImage: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = entry.text
        withAnimation {
            showingCopiedMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopiedMessage = false
            }
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(HistoryService.shared)
}
