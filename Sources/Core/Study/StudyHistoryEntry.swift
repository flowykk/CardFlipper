import Foundation

public struct StudyHistoryEntry: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let mode: StudyMode
    public let direction: StudyDirection
    public let selectedTagNames: [String]
    public let plannedCardCount: Int
    public let completedCardCount: Int
    public let encounteredCardCount: Int
    public let repeatedCardCount: Int
    public let forgottenCount: Int
    public let totalAssessmentCount: Int
    public let elapsedSeconds: Int
    public let difficultCardTitles: [String]

    public init(
        id: UUID,
        startedAt: Date,
        completedAt: Date,
        mode: StudyMode,
        direction: StudyDirection,
        selectedTagNames: [String],
        plannedCardCount: Int,
        completedCardCount: Int,
        encounteredCardCount: Int,
        repeatedCardCount: Int,
        forgottenCount: Int,
        totalAssessmentCount: Int,
        elapsedSeconds: Int,
        difficultCardTitles: [String]
    ) {
        let normalizedPlannedCardCount = max(0, plannedCardCount)
        let normalizedEncounteredCardCount = min(
            normalizedPlannedCardCount,
            max(0, encounteredCardCount)
        )
        let normalizedTotalAssessmentCount = max(0, totalAssessmentCount)

        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.mode = mode
        self.direction = direction
        self.selectedTagNames = Self.sortedUnique(selectedTagNames)
        self.plannedCardCount = normalizedPlannedCardCount
        self.completedCardCount = min(
            normalizedEncounteredCardCount,
            max(0, completedCardCount)
        )
        self.encounteredCardCount = normalizedEncounteredCardCount
        self.repeatedCardCount = min(
            normalizedEncounteredCardCount,
            max(0, repeatedCardCount)
        )
        self.forgottenCount = min(normalizedTotalAssessmentCount, max(0, forgottenCount))
        self.totalAssessmentCount = normalizedTotalAssessmentCount
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.difficultCardTitles = Self.sortedUnique(difficultCardTitles)
    }

    public var recallRatePercentage: Int {
        guard encounteredCardCount > 0 else { return 0 }
        let recalled = max(0, encounteredCardCount - repeatedCardCount)
        return Int((Double(recalled) / Double(encounteredCardCount) * 100).rounded())
    }

    private static func sortedUnique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }.sorted()
    }
}
