public enum StudySessionError: Error, Equatable, Sendable {
    case answerNotRevealed
}

public struct StudyResult: Equatable, Sendable {
    public let uniqueCardCount: Int
    public let forgottenCount: Int

    public init(uniqueCardCount: Int, forgottenCount: Int) {
        self.uniqueCardCount = uniqueCardCount
        self.forgottenCount = forgottenCount
    }
}

public struct StudySession: Sendable {
    public let direction: StudyDirection
    public let initialCardCount: Int
    public private(set) var queue: [VocabularyCard]
    public private(set) var forgottenCount = 0
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
        queue.removeFirst()
        isRevealed = false
    }

    public mutating func forget() throws {
        guard isRevealed else { throw StudySessionError.answerNotRevealed }
        let forgottenCard = queue.removeFirst()
        queue.append(forgottenCard)
        forgottenCount += 1
        isRevealed = false
    }
}
