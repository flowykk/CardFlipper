import ActivityKit
import Foundation

@MainActor
public final class SystemStudyTimerLiveActivityClient: StudyTimerLiveActivityClient {
    private var activity: Activity<StudyTimerActivityAttributes>?

    public init() {}

    public func cleanupOrphans() {
        let activities = Activity<StudyTimerActivityAttributes>.activities
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    public func start(snapshot: StudyTimerSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        cleanupOrphans()
        do {
            activity = try Activity.request(
                attributes: StudyTimerActivityAttributes(),
                content: content(snapshot: snapshot, phase: .running),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    public func publish(snapshot: StudyTimerSnapshot, phase: StudyTimerActivityAttributes.Phase) {
        guard let activity else { return }
        let content = content(snapshot: snapshot, phase: phase)
        Task { await activity.update(content) }
    }

    public func end(finalSnapshot: StudyTimerSnapshot) {
        guard let activity else { return }
        self.activity = nil
        let content = content(snapshot: finalSnapshot, phase: .paused)
        Task { await activity.end(content, dismissalPolicy: .immediate) }
    }

    private func content(
        snapshot: StudyTimerSnapshot,
        phase: StudyTimerActivityAttributes.Phase
    ) -> ActivityContent<StudyTimerActivityAttributes.ContentState> {
        ActivityContent(
            state: StudyTimerActivityAttributes.ContentState(
                dailyElapsedSeconds: snapshot.todayElapsedSeconds,
                sessionElapsedSeconds: snapshot.sessionElapsedSeconds,
                phase: phase,
                updatedAt: .now
            ),
            staleDate: nil
        )
    }
}
