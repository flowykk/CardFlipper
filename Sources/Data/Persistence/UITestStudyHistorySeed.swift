#if DEBUG
import Core
import Foundation
import SwiftData

/// Fixed UI fixtures. Launch configuration always isolates these from user data.
public enum UITestStudyHistorySeed {
    public static var resumableSnapshot: StudySessionSnapshot {
        let cards = Array(UITestVocabularySeed.cardIDs.prefix(2))
        return StudySessionSnapshot(
            direction: .russianToEnglish,
            selectedTagIDs: [],
            originalCardIDs: cards,
            queueCardIDs: [cards[1]],
            isShowingAnswer: false,
            isRevealed: false,
            forgottenCount: 0,
            repeatedCardIDs: [],
            totalAssessmentCount: 1,
            startedAt: Date(timeIntervalSince1970: 1_789_286_400),
            accumulatedDurationSeconds: 30,
            sessionID: seedID(900),
            lastActivityAt: Date(timeIntervalSince1970: 1_789_286_430),
            encounteredCardIDs: [cards[0]],
            completedCardIDs: [cards[0]],
            cardDisplaySnapshots: [
                StudyCardDisplaySnapshot(id: cards[0], title: "book"),
                StudyCardDisplaySnapshot(id: cards[1], title: "cat"),
            ]
        )
    }

    @MainActor
    public static func insert(into container: ModelContainer) throws {
        let repository = SwiftDataStudyHistoryRepository(container: container)
        // Insert oldest first so UI ordering must come from the repository/model.
        try repository.insertIfNeeded(StudyHistoryEntry(
            id: seedID(901),
            startedAt: Date(timeIntervalSince1970: 1_789_200_000),
            completedAt: Date(timeIntervalSince1970: 1_789_200_001),
            mode: .flashcards,
            direction: .englishToRussian,
            selectedTagNames: [],
            plannedCardCount: 3,
            completedCardCount: 3,
            encounteredCardCount: 3,
            repeatedCardCount: 0,
            forgottenCount: 0,
            totalAssessmentCount: 3,
            elapsedSeconds: 1,
            difficultCardTitles: []
        ))
        try repository.insertIfNeeded(StudyHistoryEntry(
            id: seedID(902),
            startedAt: Date(timeIntervalSince1970: 1_789_286_400),
            completedAt: Date(timeIntervalSince1970: 1_789_286_461),
            mode: .writing,
            direction: .russianToEnglish,
            selectedTagNames: ["Основы"],
            plannedCardCount: 3,
            completedCardCount: 2,
            encounteredCardCount: 2,
            repeatedCardCount: 1,
            forgottenCount: 2,
            totalAssessmentCount: 4,
            elapsedSeconds: 61,
            difficultCardTitles: ["book"]
        ))
    }

    private static func seedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
#endif
