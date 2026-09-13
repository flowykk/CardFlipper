import Foundation

public struct StudySessionSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
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
    public let accumulatedDurationSeconds: Int
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
        completedResult: StudyResult? = nil
    ) {
        self.version = version
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
        self.accumulatedDurationSeconds = max(0, accumulatedDurationSeconds)
        self.completedResult = completedResult
    }

    private enum CodingKeys: String, CodingKey {
        case version
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
        case accumulatedDurationSeconds
        case completedResult
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
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
        accumulatedDurationSeconds = max(
            0,
            try container.decode(Int.self, forKey: .accumulatedDurationSeconds)
        )
        completedResult = try container.decodeIfPresent(StudyResult.self, forKey: .completedResult)
    }
}
