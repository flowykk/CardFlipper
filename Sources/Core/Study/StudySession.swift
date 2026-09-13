import Foundation

public enum StudySessionError: Error, Equatable, Sendable {
    case answerNotRevealed
    case noCurrentCard
}

public struct StudyResult: Codable, Equatable, Sendable {
    public let plannedCardCount: Int
    public let completedCardCount: Int
    public let encounteredCardCount: Int
    public let repeatedCardIDs: [UUID]
    public let totalAssessmentCount: Int
    public let elapsedSeconds: Int

    public init(
        plannedCardCount: Int,
        completedCardCount: Int,
        encounteredCardIDs: Set<UUID>,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        elapsedSeconds: Int
    ) {
        self.init(
            plannedCardCount: plannedCardCount,
            completedCardCount: completedCardCount,
            encounteredCardCount: encounteredCardIDs.count,
            repeatedCardIDs: repeatedCardIDs.filter { encounteredCardIDs.contains($0) },
            totalAssessmentCount: totalAssessmentCount,
            elapsedSeconds: elapsedSeconds
        )
    }

    public init(
        reviewedCardCount: Int,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        elapsedSeconds: Int
    ) {
        let reviewedCardCount = max(0, reviewedCardCount)
        self.init(
            plannedCardCount: reviewedCardCount,
            completedCardCount: reviewedCardCount,
            encounteredCardCount: reviewedCardCount,
            repeatedCardIDs: repeatedCardIDs,
            totalAssessmentCount: totalAssessmentCount,
            elapsedSeconds: elapsedSeconds
        )
    }

    public init(uniqueCardCount: Int, forgottenCount: Int) {
        self.init(
            reviewedCardCount: uniqueCardCount,
            repeatedCardIDs: [],
            totalAssessmentCount: uniqueCardCount + forgottenCount,
            elapsedSeconds: 0
        )
    }

    public var reviewedCardCount: Int { completedCardCount }
    public var uniqueCardCount: Int { completedCardCount }
    public var forgottenCount: Int { max(0, totalAssessmentCount - completedCardCount) }
    public var repeatedCardCount: Int { repeatedCardIDs.count }

    public var recallRatePercentage: Int {
        guard encounteredCardCount > 0 else { return 0 }
        return Int(
            (Double(max(0, encounteredCardCount - repeatedCardCount)) / Double(encounteredCardCount) * 100)
                .rounded()
        )
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private init(
        plannedCardCount: Int,
        completedCardCount: Int,
        encounteredCardCount: Int,
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        elapsedSeconds: Int
    ) {
        self.plannedCardCount = max(0, plannedCardCount)
        self.encounteredCardCount = min(self.plannedCardCount, max(0, encounteredCardCount))
        self.completedCardCount = min(self.encounteredCardCount, max(0, completedCardCount))
        self.repeatedCardIDs = Array(Self.unique(repeatedCardIDs).prefix(self.encounteredCardCount))
        self.totalAssessmentCount = max(0, totalAssessmentCount)
        self.elapsedSeconds = max(0, elapsedSeconds)
    }
}

public struct StudySession: Sendable {
    public let direction: StudyDirection
    public let initialCardCount: Int
    public private(set) var queue: [VocabularyCard]
    public private(set) var forgottenCount = 0
    public private(set) var encounteredCardIDs: Set<UUID> = []
    public private(set) var completedCardIDs: Set<UUID> = []
    public private(set) var repeatedCardIDs: [UUID] = []
    public private(set) var totalAssessmentCount = 0
    public private(set) var isRevealed = false

    public init(cards: [VocabularyCard], direction: StudyDirection) {
        self.direction = direction
        initialCardCount = cards.count
        queue = cards
    }

    public init(
        cards: [VocabularyCard],
        direction: StudyDirection,
        initialCardCount: Int,
        forgottenCount: Int,
        encounteredCardIDs: Set<UUID> = [],
        completedCardIDs: Set<UUID> = [],
        repeatedCardIDs: [UUID],
        totalAssessmentCount: Int,
        isRevealed: Bool
    ) {
        self.direction = direction
        self.initialCardCount = max(cards.count, initialCardCount)
        queue = cards
        self.forgottenCount = max(0, forgottenCount)
        self.encounteredCardIDs = encounteredCardIDs
        self.completedCardIDs = completedCardIDs
        self.repeatedCardIDs = repeatedCardIDs
        self.totalAssessmentCount = max(0, totalAssessmentCount)
        self.isRevealed = isRevealed && !cards.isEmpty
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
        let rememberedCard = queue.removeFirst()
        encounteredCardIDs.insert(rememberedCard.id)
        completedCardIDs.insert(rememberedCard.id)
        totalAssessmentCount += 1
        isRevealed = false
    }

    public mutating func forget() throws {
        guard isRevealed else { throw StudySessionError.answerNotRevealed }
        guard !queue.isEmpty else { throw StudySessionError.noCurrentCard }
        encounteredCardIDs.insert(queue[0].id)
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
