import SwiftUI

struct SpokenPunctuationReferenceView: View {
    var body: some View {
        List {
            Section("Always") {
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

            Section {
                LabeledContent("minus", value: "-")
                LabeledContent("dot", value: ".")
                LabeledContent("colon", value: ":")
                LabeledContent("dollar", value: "$")
            } header: {
                Text("Between identifier words")
            } footer: {
                Text("Conditional symbols collapse only when flanked by identifier-shaped words (e.g. \"Claude minus ops\" → \"Claude-ops\"). \"dot\" also collapses between number-words (\"ten dot five\" → \"10.5\").")
            }
        }
        .navigationTitle("Spoken Punctuation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SpokenPunctuationReferenceView()
    }
}
