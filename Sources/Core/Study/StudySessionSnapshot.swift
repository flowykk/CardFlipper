import Foundation

public struct StudySessionSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let direction: StudyDirection
    public let selectedTagIDs: Set<UUID>
    public let originalCardIDs: [UUID]
    public let queueCardIDs: [UUID]
    public let isShowingAnswer: Bool
    public let isRevealed: Bool
    public let forgottenCount: Int
    public let repeatedCardIDs: [UUID]
    public let totalAssessmentCount: Int
    public let startedAt: Date
    public let accumulatedDurationSeconds: Int
    public let completedResult: StudyResult?

    public init(
        version: Int = Self.currentVersion,
        direction: StudyDirection,
        selectedTagIDs: Set<UUID>,
        originalCardIDs: [UUID],
        queueCardIDs: [UUID],
        isShowingAnswer: Bool,
        isRevealed: Bool,
        forgottenCount: Int,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        startedAt: Date = Date(),
        accumulatedDurationSeconds: Int,
        completedResult: StudyResult? = nil
    ) {
        self.version = version
        self.direction = direction
        self.selectedTagIDs = selectedTagIDs
        self.originalCardIDs = originalCardIDs
        self.queueCardIDs = queueCardIDs
        self.isShowingAnswer = isShowingAnswer
        self.isRevealed = isRevealed
        self.forgottenCount = max(0, forgottenCount)
        self.repeatedCardIDs = repeatedCardIDs
        self.totalAssessmentCount = max(0, totalAssessmentCount)
        self.startedAt = startedAt
        self.accumulatedDurationSeconds = max(0, accumulatedDurationSeconds)
        self.completedResult = completedResult
    }
}
