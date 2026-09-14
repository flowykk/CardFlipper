import Foundation
import Observation

@MainActor
@Observable
public final class StudyTimerController {
    public private(set) var snapshot: StudyTimerSnapshot = .hidden

    private let progress: any DailyProgressRepository
    private let liveActivity: any StudyTimerLiveActivityClient
    private let calendar: Calendar
    private let now: () -> Date

    private var sessionID: UUID?
    private var sceneIsActive = false
    private var isEditing = false
    private var activeSegmentStart: Date?
    private var committedSessionSeconds = 0
    private var nextCheckpoint: Date?

    public init(
        progress: any DailyProgressRepository,
        liveActivity: any StudyTimerLiveActivityClient = DisabledStudyTimerLiveActivityClient(),
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.progress = progress
        self.liveActivity = liveActivity
        self.calendar = calendar
        self.now = now
    }

    public func startSession(id: UUID) {
        if sessionID == id { return }
        if sessionID != nil, let existing = sessionID {
            endSession(id: existing)
        }
        sessionID = id
        isEditing = false
        committedSessionSeconds = 0
        let date = now()
        if sceneIsActive && !isEditing {
            beginSegment(at: date)
        }
        refresh(at: date, visible: true)
        liveActivity.start(snapshot: snapshot)
    }

    public func setSceneActive(_ isActive: Bool) {
        guard sceneIsActive != isActive else { return }
        sceneIsActive = isActive
        guard sessionID != nil else { return }
        let date = now()
        if isActive && !isEditing {
            beginSegment(at: date)
            refresh(at: date, visible: true)
            liveActivity.publish(snapshot: snapshot, phase: .running)
        } else {
            commitSegment(endingAt: date)
            refresh(at: date, visible: true)
            liveActivity.publish(snapshot: snapshot, phase: .paused)
        }
    }

    public func setEditing(_ editing: Bool) {
        guard isEditing != editing else { return }
        isEditing = editing
        guard sessionID != nil else { return }
        let date = now()
        if sceneIsActive && !isEditing {
            beginSegment(at: date)
        } else {
            commitSegment(endingAt: date)
        }
        refresh(at: date, visible: true)
        liveActivity.publish(snapshot: snapshot, phase: sceneIsActive && !isEditing ? .running : .paused)
    }

    public func tick() {
        guard sessionID != nil else { return }
        let date = now()
        if let checkpoint = nextCheckpoint, date >= checkpoint {
            commitSegment(endingAt: date)
            if sceneIsActive && !isEditing { beginSegment(at: date) }
        }
        refresh(at: date, visible: true)
    }

    public func endSession(id: UUID) {
        guard sessionID == id else { return }
        let date = now()
        commitSegment(endingAt: date)
        refresh(at: date, visible: false)
        liveActivity.end(finalSnapshot: snapshot)
        sessionID = nil
        activeSegmentStart = nil
        nextCheckpoint = nil
    }

    public func cleanupOrphanedActivity() {
        liveActivity.cleanupOrphans()
    }

    private func beginSegment(at date: Date) {
        guard activeSegmentStart == nil else { return }
        activeSegmentStart = date
        nextCheckpoint = date.addingTimeInterval(60)
    }

    private func commitSegment(endingAt end: Date) {
        guard let start = activeSegmentStart else { return }
        let counted = progress.recordActiveInterval(from: start, to: end, calendar: calendar)
        committedSessionSeconds += counted
        activeSegmentStart = nil
        nextCheckpoint = nil
    }

    private func refresh(at date: Date, visible: Bool) {
        let uncommitted = activeSegmentStart.map {
            max(0, Int(date.timeIntervalSince($0).rounded(.down)))
        } ?? 0
        let today = progress.progress(for: date, calendar: calendar).elapsedSeconds + uncommitted
        snapshot = StudyTimerSnapshot(
            todayElapsedSeconds: today,
            sessionElapsedSeconds: committedSessionSeconds + uncommitted,
            isVisible: visible
        )
    }
}
