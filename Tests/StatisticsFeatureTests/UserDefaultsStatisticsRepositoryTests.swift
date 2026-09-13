import Core
import Foundation
import StatisticsFeature
import Testing

@MainActor
@Test func completedSessionsAccumulateAndPersistUsefulStatistics() {
    let defaults = makeIsolatedDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let repository = UserDefaultsStatisticsRepository(defaults: defaults)

    repository.record(
        sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        mode: .flashcards,
        result: StudyResult(uniqueCardCount: 4, forgottenCount: 0)
    )
    repository.record(
        sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        mode: .writing,
        result: StudyResult(uniqueCardCount: 6, forgottenCount: 2)
    )

    let restored = UserDefaultsStatisticsRepository(defaults: defaults).statistics

    #expect(restored.completedLessonCount == 2)
    #expect(restored.studiedCardCount == 10)
    #expect(restored.forgottenCount == 2)
    #expect(restored.averageCardsPerLesson == 5)
    #expect(restored.lessonsWithoutForgettingPercentage == 50)
    #expect(restored.totalAssessmentCount == 12)
    #expect(restored.flashcards.completedLessonCount == 1)
    #expect(restored.flashcards.studiedCardCount == 4)
    #expect(restored.writing.completedLessonCount == 1)
    #expect(restored.writing.studiedCardCount == 6)
    #expect(restored.writing.forgottenCount == 2)
}

@MainActor
@Test func recordingTheSameSessionTwiceDoesNotChangeTotals() {
    let defaults = makeIsolatedDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let repository = UserDefaultsStatisticsRepository(defaults: defaults)
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let result = StudyResult(uniqueCardCount: 3, forgottenCount: 1)

    repository.record(sessionID: sessionID, mode: .writing, result: result)
    repository.record(sessionID: sessionID, mode: .writing, result: result)

    #expect(repository.statistics.completedLessonCount == 1)
    #expect(repository.statistics.studiedCardCount == 3)
    #expect(repository.statistics.forgottenCount == 1)
    #expect(repository.statistics.flashcards.completedLessonCount == 0)
    #expect(repository.statistics.writing.completedLessonCount == 1)
}

@MainActor
@Test func partialSessionUsesCompletedCardsForTotalsAndEncounteredCardsForRecall() {
    let defaults = makeIsolatedDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let repository = UserDefaultsStatisticsRepository(defaults: defaults)
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let encounteredCardIDs: Set<UUID> = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000041")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000043")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000044")!
    ]
    let repeatedCardID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
    let result = StudyResult(
        plannedCardCount: 10,
        completedCardCount: 3,
        encounteredCardIDs: encounteredCardIDs,
        repeatedCardIDs: [repeatedCardID],
        totalAssessmentCount: 4,
        elapsedSeconds: 0
    )

    repository.record(sessionID: sessionID, mode: .flashcards, result: result)

    #expect(repository.statistics.studiedCardCount == 3)
    #expect(repository.statistics.encounteredCardCount == 4)
    #expect(repository.statistics.firstTryRecallPercentage == 75)

    let totalsAfterFirstRecord = repository.statistics
    repository.record(sessionID: sessionID, mode: .flashcards, result: result)

    #expect(repository.statistics == totalsAfterFirstRecord)
}

@MainActor
@Test func legacyTotalsAreMigratedToFlashcardStatistics() throws {
    let defaults = makeIsolatedDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let legacyPayload: [String: Any] = [
        "completedLessonCount": 2,
        "studiedCardCount": 9,
        "forgottenCount": 3,
        "lessonsWithoutForgettingCount": 1,
        "repeatedCardCount": 2,
        "totalAssessmentCount": 12,
        "recordedSessionIDs": []
    ]
    defaults.set(
        try JSONSerialization.data(withJSONObject: legacyPayload),
        forKey: "statistics.completedStudySessions.v1"
    )

    let statistics = UserDefaultsStatisticsRepository(defaults: defaults).statistics

    #expect(statistics.flashcards.completedLessonCount == 2)
    #expect(statistics.flashcards.studiedCardCount == 9)
    #expect(statistics.flashcards.encounteredCardCount == 9)
    #expect(statistics.flashcards.repeatedCardCount == 2)
    #expect(statistics.writing == .zero)
}

private let defaultsSuiteName = "StatisticsFeatureTests.UserDefaultsStatisticsRepository"

private func makeIsolatedDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: defaultsSuiteName)!
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    return defaults
}
