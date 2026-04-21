import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "mic.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Dicticus iOS Scaffold")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
