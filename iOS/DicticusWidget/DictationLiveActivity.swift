import WidgetKit
import SwiftUI
import AppIntents

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
                    HStack {
                        Text("Tap to open Dicticus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if context.state.isRecording {
                            Button(intent: StopDictationIntent()) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(Circle().fill(Color.red))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
