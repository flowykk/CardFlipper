import Foundation

@MainActor
public protocol StudyTimerLiveActivityClient: AnyObject {
    func cleanupOrphans()
    func start(snapshot: StudyTimerSnapshot)
    func publish(snapshot: StudyTimerSnapshot, phase: StudyTimerActivityAttributes.Phase)
    func end(finalSnapshot: StudyTimerSnapshot)
}

@MainActor
public final class DisabledStudyTimerLiveActivityClient: StudyTimerLiveActivityClient {
    public init() {}
    public func cleanupOrphans() {}
    public func start(snapshot: StudyTimerSnapshot) {}
    public func publish(snapshot: StudyTimerSnapshot, phase: StudyTimerActivityAttributes.Phase) {}
    public func end(finalSnapshot: StudyTimerSnapshot) {}
}
