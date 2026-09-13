import Foundation

public enum WritingSessionError: Error, Equatable, Sendable {
    case noCurrentCard
    case answerNotCorrect
}

public struct WritingSession: Sendable {
    public let initialCardCount: Int
    public private(set) var queue: [VocabularyCard]
    public private(set) var response: String
    public private(set) var evaluation: WritingAnswerEvaluation
    public private(set) var isShowingAnswer: Bool
    public private(set) var hasRevealedAnswer: Bool
    public private(set) var forgottenCount: Int
    public private(set) var repeatedCardIDs: [UUID]
    public private(set) var totalAssessmentCount: Int

    public init(cards: [VocabularyCard]) {
        initialCardCount = cards.count
        queue = cards
        response = ""
        evaluation = .unanswered
        isShowingAnswer = false
        hasRevealedAnswer = false
        forgottenCount = 0
        repeatedCardIDs = []
        totalAssessmentCount = 0
    }

    public init(
        cards: [VocabularyCard],
        initialCardCount: Int,
        response: String,
        evaluation: WritingAnswerEvaluation,
        isShowingAnswer: Bool,
        hasRevealedAnswer: Bool,
        forgottenCount: Int,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int
    ) {
        queue = cards
        self.initialCardCount = max(cards.count, initialCardCount)
        self.response = response
        self.evaluation = cards.isEmpty ? .unanswered : evaluation
        self.isShowingAnswer = isShowingAnswer && !cards.isEmpty
        self.hasRevealedAnswer = hasRevealedAnswer && !cards.isEmpty
        self.forgottenCount = max(0, forgottenCount)
        self.repeatedCardIDs = repeatedCardIDs
        self.totalAssessmentCount = max(0, totalAssessmentCount)
    }

    public var currentCard: VocabularyCard? { queue.first }
    public var remainingCount: Int { queue.count }
    public var isComplete: Bool { queue.isEmpty }

    public mutating func setResponse(_ response: String) {
        guard evaluation != .correct else { return }
        self.response = response
        if evaluation == .incorrect {
            evaluation = .unanswered
        }
    }

    @discardableResult
    public mutating func checkResponse() -> WritingAnswerEvaluation {
        guard let currentCard else { return .unanswered }
        guard evaluation != .correct else { return .correct }

        let responseKey = TextNormalizer.searchKey(response)
        let isCorrect = !responseKey.isEmpty && currentCard.englishVariants.contains {
            TextNormalizer.searchKey($0.text) == responseKey
        }

        totalAssessmentCount += 1
        if isCorrect {
            evaluation = .correct
        } else {
            evaluation = .incorrect
            forgottenCount += 1
            markCurrentCardDifficult()
        }
        return evaluation
    }

    public mutating func toggleAnswer() {
        guard currentCard != nil else { return }
        isShowingAnswer.toggle()
        guard isShowingAnswer, !hasRevealedAnswer else { return }

        hasRevealedAnswer = true
        guard evaluation != .correct,
              let currentCard,
              !repeatedCardIDs.contains(currentCard.id) else {
            return
        }
        forgottenCount += 1
        totalAssessmentCount += 1
        repeatedCardIDs.append(currentCard.id)
    }

    public mutating func remember() throws {
        guard currentCard != nil else { throw WritingSessionError.noCurrentCard }
        guard evaluation == .correct else { throw WritingSessionError.answerNotCorrect }

        queue.removeFirst()
        resetWritingState()
    }

    public mutating func forget() throws {
        guard let currentCard else { throw WritingSessionError.noCurrentCard }
        guard evaluation == .correct else { throw WritingSessionError.answerNotCorrect }

        queue.removeFirst()
        queue.append(currentCard)
        forgottenCount += 1
        totalAssessmentCount += 1
        if !repeatedCardIDs.contains(currentCard.id) {
            repeatedCardIDs.append(currentCard.id)
        }
        resetWritingState()
    }

    private mutating func resetWritingState() {
        response = ""
        evaluation = .unanswered
        isShowingAnswer = false
        hasRevealedAnswer = false
    }

    private mutating func markCurrentCardDifficult() {
        guard let currentCard, !repeatedCardIDs.contains(currentCard.id) else { return }
        repeatedCardIDs.append(currentCard.id)
    }
}
