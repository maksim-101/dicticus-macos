import WidgetKit
import SwiftUI

struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationAttributes.self) { context in
            HStack {
                Image(systemName: "mic.fill").foregroundColor(.red)
                Text(context.state.isRecording ? "Recording\u{2026}" : "Processing\u{2026}")
                Spacer()
                Text("\(context.state.elapsedSeconds)s")
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill").foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isRecording ? "Recording" : "Processing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Tap to open Dicticus")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "mic.fill").foregroundColor(.red)
            } compactTrailing: {
                Text("\(context.state.elapsedSeconds)s").monospacedDigit()
            } minimal: {
                Image(systemName: "mic.fill").foregroundColor(.red)
            }
        }
    }
}
