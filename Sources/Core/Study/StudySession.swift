import Foundation

public enum StudySessionError: Error, Equatable, Sendable {
    case answerNotRevealed
    case noCurrentCard
}

public struct StudyResult: Equatable, Sendable {
    public let reviewedCardCount: Int
    public let repeatedCardIDs: [UUID]
    public let totalAssessmentCount: Int
    public let elapsedSeconds: Int

    public init(
        reviewedCardCount: Int,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        elapsedSeconds: Int
    ) {
        self.reviewedCardCount = reviewedCardCount
        self.repeatedCardIDs = repeatedCardIDs
        self.totalAssessmentCount = totalAssessmentCount
        self.elapsedSeconds = max(0, elapsedSeconds)
    }

    public init(uniqueCardCount: Int, forgottenCount: Int) {
        self.init(
            reviewedCardCount: uniqueCardCount,
            repeatedCardIDs: [],
            totalAssessmentCount: uniqueCardCount + forgottenCount,
            elapsedSeconds: 0
        )
    }

    public var uniqueCardCount: Int { reviewedCardCount }
    public var forgottenCount: Int { max(0, totalAssessmentCount - reviewedCardCount) }
    public var repeatedCardCount: Int { repeatedCardIDs.count }

    public var recallRatePercentage: Int {
        guard reviewedCardCount > 0 else { return 0 }
        return Int(
            (Double(reviewedCardCount - repeatedCardCount) / Double(reviewedCardCount) * 100)
                .rounded()
        )
    }
}

public struct StudySession: Sendable {
    public let direction: StudyDirection
    public let initialCardCount: Int
    public private(set) var queue: [VocabularyCard]
    public private(set) var forgottenCount = 0
    public private(set) var repeatedCardIDs: [UUID] = []
    public private(set) var totalAssessmentCount = 0
    public private(set) var isRevealed = false

    public init(cards: [VocabularyCard], direction: StudyDirection) {
        self.direction = direction
        initialCardCount = cards.count
        queue = cards
    }

    public var currentCard: VocabularyCard? { queue.first }
    public var remainingCount: Int { queue.count }
    public var isComplete: Bool { queue.isEmpty }

    public mutating func reveal() {
        isRevealed = true
    }

    public mutating func remember() throws {
        guard isRevealed else { throw StudySessionError.answerNotRevealed }
        guard !queue.isEmpty else { throw StudySessionError.noCurrentCard }
        queue.removeFirst()
        totalAssessmentCount += 1
        isRevealed = false
    }

    public mutating func forget() throws {
        guard isRevealed else { throw StudySessionError.answerNotRevealed }
        guard !queue.isEmpty else { throw StudySessionError.noCurrentCard }
        let forgottenCard = queue.removeFirst()
        queue.append(forgottenCard)
        forgottenCount += 1
        totalAssessmentCount += 1
        if !repeatedCardIDs.contains(forgottenCard.id) {
            repeatedCardIDs.append(forgottenCard.id)
        }
        isRevealed = false
    }
}
