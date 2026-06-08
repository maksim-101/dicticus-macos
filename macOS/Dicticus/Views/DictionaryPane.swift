import SwiftUI

/// Dictionary pane of the popover: quick actions for the custom dictionary (UIORG-01).
///
/// Exposes Add / Manage Full Dictionary / Import / Export without scrolling past unrelated
/// controls. All four actions open the DictionaryView window (the existing Phase 31 engine
/// is unchanged per UIORG-04). Add and Import/Export deep-link by opening the full manager
/// where those controls live, rather than reimplementing the flow here.
struct DictionaryPane: View {

    @Environment(\.openWindow) private var openWindow

    /// Entry count from the shared DictionaryService for the section header badge.
    @ObservedObject private var dictionaryService = DictionaryService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Section header with entry count badge
                HStack {
                    Text("Custom Dictionary")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    let count = dictionaryService.dictionary.count
                    Text("\(count) \(count == 1 ? "entry" : "entries")")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }

                // + Add Entry — opens dictionary manager (Add row is always visible in DictionaryView)
                Button("+ Add Entry") {
                    openDictionaryWindow()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Add dictionary entry")

                // Manage Full Dictionary…
                Button("Manage Full Dictionary…") {
                    openDictionaryWindow()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Open full dictionary manager")

                // Import / Export row
                HStack(spacing: 8) {
                    Button("Import…") {
                        openDictionaryWindow()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Import dictionary")

                    Button("Export…") {
                        openDictionaryWindow()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Export dictionary")
                }

                Text("Starter packs and spoken-punctuation reference are in the full manager.")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private func openDictionaryWindow() {
        openWindow(id: "dictionary")
        NSApp.activate(ignoringOtherApps: true)
    }
}
