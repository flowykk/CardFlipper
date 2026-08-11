import Foundation

public struct StudyTimerSnapshot: Equatable, Sendable {
    public let todayElapsedSeconds: Int
    public let sessionElapsedSeconds: Int
    public let isVisible: Bool

    public init(todayElapsedSeconds: Int, sessionElapsedSeconds: Int, isVisible: Bool) {
        self.todayElapsedSeconds = todayElapsedSeconds
        self.sessionElapsedSeconds = sessionElapsedSeconds
        self.isVisible = isVisible
    }

    public static let hidden = StudyTimerSnapshot(
        todayElapsedSeconds: 0,
        sessionElapsedSeconds: 0,
        isVisible: false
    )
}
