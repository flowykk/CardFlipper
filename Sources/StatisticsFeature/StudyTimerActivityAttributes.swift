import ActivityKit
import Foundation

public struct StudyTimerActivityAttributes: ActivityAttributes {
    public enum Phase: String, Codable, Hashable, Sendable {
        case running
        case paused
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public let dailyElapsedSeconds: Int
        public let sessionElapsedSeconds: Int
        public let phase: Phase
        public let updatedAt: Date

        public init(
            dailyElapsedSeconds: Int,
            sessionElapsedSeconds: Int,
            phase: Phase,
            updatedAt: Date
        ) {
            self.dailyElapsedSeconds = dailyElapsedSeconds
            self.sessionElapsedSeconds = sessionElapsedSeconds
            self.phase = phase
            self.updatedAt = updatedAt
        }
    }

    public init() {}
}
