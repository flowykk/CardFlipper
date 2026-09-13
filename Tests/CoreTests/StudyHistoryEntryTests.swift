import Foundation
import Testing
@testable import Core

@Test func partialHistoryIgnoresUnseenCardsInRecall() {
    let entry = StudyHistoryEntry(
        id: UUID(),
        startedAt: Date(timeIntervalSince1970: 100),
        completedAt: Date(timeIntervalSince1970: 160),
        mode: .flashcards,
        direction: .englishToRussian,
        selectedTagNames: ["Basics"],
        plannedCardCount: 10,
        completedCardCount: 3,
        encounteredCardCount: 4,
        repeatedCardCount: 1,
        forgottenCount: 2,
        totalAssessmentCount: 6,
        elapsedSeconds: 60,
        difficultCardTitles: ["book"]
    )

    #expect(entry.recallRatePercentage == 75)
    #expect(entry.completedCardCount == 3)
    #expect(entry.plannedCardCount == 10)
}

@Test func historyWithNoAssessedCardsHasZeroRecall() {
    let entry = StudyHistoryEntry(
        id: UUID(),
        startedAt: .distantPast,
        completedAt: .distantPast,
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagNames: [],
        plannedCardCount: 2,
        completedCardCount: 0,
        encounteredCardCount: 0,
        repeatedCardCount: 0,
        forgottenCount: 0,
        totalAssessmentCount: 0,
        elapsedSeconds: 0,
        difficultCardTitles: []
    )

    #expect(entry.recallRatePercentage == 0)
}

@Test func historyClampsInvalidCountsAndDeduplicatesDisplayNames() {
    let entry = StudyHistoryEntry(
        id: UUID(),
        startedAt: .distantPast,
        completedAt: .distantPast,
        mode: .flashcards,
        direction: .russianToEnglish,
        selectedTagNames: ["Zulu", "Alpha", "Zulu"],
        plannedCardCount: 2,
        completedCardCount: 5,
        encounteredCardCount: 4,
        repeatedCardCount: 6,
        forgottenCount: -1,
        totalAssessmentCount: -2,
        elapsedSeconds: -3,
        difficultCardTitles: ["zebra", "apple", "zebra"]
    )

    #expect(entry.completedCardCount == 2)
    #expect(entry.encounteredCardCount == 2)
    #expect(entry.repeatedCardCount == 2)
    #expect(entry.forgottenCount == 0)
    #expect(entry.totalAssessmentCount == 0)
    #expect(entry.elapsedSeconds == 0)
    #expect(entry.recallRatePercentage == 0)
    #expect(entry.selectedTagNames == ["Alpha", "Zulu"])
    #expect(entry.difficultCardTitles == ["apple", "zebra"])
}
