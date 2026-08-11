import ActivityKit
import StatisticsFeature
import SwiftUI
import WidgetKit

struct StudyTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyTimerActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusKey(context.state.phase))
                        .font(.headline)
                    Text(display(context.state))
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.08))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("activity.title", systemImage: "timer")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(StudyDurationFormatter.string(seconds: context.state.dailyElapsedSeconds))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(display(context.state))
                        .font(.system(.headline, design: .monospaced))
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(StudyDurationFormatter.string(seconds: context.state.dailyElapsedSeconds))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func display(_ state: StudyTimerActivityAttributes.ContentState) -> String {
        "\(StudyDurationFormatter.string(seconds: state.dailyElapsedSeconds)) / +\(StudyDurationFormatter.string(seconds: state.sessionElapsedSeconds))"
    }

    private func statusKey(_ phase: StudyTimerActivityAttributes.Phase) -> LocalizedStringKey {
        phase == .paused ? "activity.paused" : "activity.running"
    }
}
