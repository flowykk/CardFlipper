import Foundation

public enum StudySessionSnapshotError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
}

public struct StudySessionSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 2

    public let version: Int
    public let sessionID: UUID
    public let mode: StudyMode
    public let direction: StudyDirection
    public let selectedTagIDs: Set<UUID>
    public let originalCardIDs: [UUID]
    public let queueCardIDs: [UUID]
    public let isShowingAnswer: Bool
    public let isRevealed: Bool
    public let forgottenCount: Int
    public let repeatedCardIDs: [UUID]
    public let totalAssessmentCount: Int
    public let writingResponse: String
    public let writingEvaluation: WritingAnswerEvaluation
    public let startedAt: Date
    public let lastActivityAt: Date
    public let accumulatedDurationSeconds: Int
    public let encounteredCardIDs: Set<UUID>
    public let completedCardIDs: Set<UUID>
    public let selectedTagNames: [String]
    public let cardDisplaySnapshots: [StudyCardDisplaySnapshot]
    public let completedResult: StudyResult?

    public init(
        version: Int = Self.currentVersion,
        mode: StudyMode = .flashcards,
        direction: StudyDirection,
        selectedTagIDs: Set<UUID>,
        originalCardIDs: [UUID],
        queueCardIDs: [UUID],
        isShowingAnswer: Bool,
        isRevealed: Bool,
        forgottenCount: Int,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        writingResponse: String = "",
        writingEvaluation: WritingAnswerEvaluation = .unanswered,
        startedAt: Date = Date(),
        accumulatedDurationSeconds: Int,
        sessionID: UUID = UUID(),
        lastActivityAt: Date? = nil,
        encounteredCardIDs: Set<UUID> = [],
        completedCardIDs: Set<UUID>? = nil,
        selectedTagNames: [String] = [],
        cardDisplaySnapshots: [StudyCardDisplaySnapshot] = [],
        completedResult: StudyResult? = nil
    ) {
        self.version = version
        self.sessionID = sessionID
        self.mode = mode
        self.direction = direction
        self.selectedTagIDs = selectedTagIDs
        self.originalCardIDs = originalCardIDs
        self.queueCardIDs = queueCardIDs
        self.isShowingAnswer = isShowingAnswer
        self.isRevealed = isRevealed
        self.forgottenCount = max(0, forgottenCount)
        self.repeatedCardIDs = repeatedCardIDs
        self.totalAssessmentCount = max(0, totalAssessmentCount)
        self.writingResponse = writingResponse
        self.writingEvaluation = writingEvaluation
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt ?? startedAt
        self.accumulatedDurationSeconds = max(0, accumulatedDurationSeconds)
        self.encounteredCardIDs = encounteredCardIDs
        self.completedCardIDs = completedCardIDs
            ?? Set(originalCardIDs).subtracting(queueCardIDs)
        self.selectedTagNames = selectedTagNames
        self.cardDisplaySnapshots = cardDisplaySnapshots
        self.completedResult = completedResult
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case sessionID
        case mode
        case direction
        case selectedTagIDs
        case originalCardIDs
        case queueCardIDs
        case isShowingAnswer
        case isRevealed
        case forgottenCount
        case repeatedCardIDs
        case totalAssessmentCount
        case writingResponse
        case writingEvaluation
        case startedAt
        case lastActivityAt
        case accumulatedDurationSeconds
        case encounteredCardIDs
        case completedCardIDs
        case selectedTagNames
        case cardDisplaySnapshots
        case completedResult
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decode(Int.self, forKey: .version)
        guard decodedVersion == 1 || decodedVersion == Self.currentVersion else {
            throw StudySessionSnapshotError.unsupportedVersion(decodedVersion)
        }
        version = Self.currentVersion
        sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID) ?? UUID()
        mode = try container.decodeIfPresent(StudyMode.self, forKey: .mode) ?? .flashcards
        direction = try container.decode(StudyDirection.self, forKey: .direction)
        selectedTagIDs = try container.decode(Set<UUID>.self, forKey: .selectedTagIDs)
        originalCardIDs = try container.decode([UUID].self, forKey: .originalCardIDs)
        queueCardIDs = try container.decode([UUID].self, forKey: .queueCardIDs)
        isShowingAnswer = try container.decode(Bool.self, forKey: .isShowingAnswer)
        isRevealed = try container.decode(Bool.self, forKey: .isRevealed)
        forgottenCount = max(0, try container.decode(Int.self, forKey: .forgottenCount))
        repeatedCardIDs = try container.decode([UUID].self, forKey: .repeatedCardIDs)
        totalAssessmentCount = max(
            0,
            try container.decode(Int.self, forKey: .totalAssessmentCount)
        )
        writingResponse = try container.decodeIfPresent(String.self, forKey: .writingResponse) ?? ""
        writingEvaluation = try container.decodeIfPresent(
            WritingAnswerEvaluation.self,
            forKey: .writingEvaluation
        ) ?? .unanswered
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt) ?? startedAt
        accumulatedDurationSeconds = max(
            0,
            try container.decode(Int.self, forKey: .accumulatedDurationSeconds)
        )
        encounteredCardIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .encounteredCardIDs) ?? []
        completedCardIDs = try container.decodeIfPresent(
            Set<UUID>.self,
            forKey: .completedCardIDs
        ) ?? Set(originalCardIDs).subtracting(queueCardIDs)
        selectedTagNames = try container.decodeIfPresent([String].self, forKey: .selectedTagNames) ?? []
        cardDisplaySnapshots = try container.decodeIfPresent(
            [StudyCardDisplaySnapshot].self,
            forKey: .cardDisplaySnapshots
        ) ?? []
        completedResult = try container.decodeIfPresent(StudyResult.self, forKey: .completedResult)
    }
}
