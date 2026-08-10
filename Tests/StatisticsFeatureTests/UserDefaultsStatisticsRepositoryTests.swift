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
        result: StudyResult(uniqueCardCount: 4, forgottenCount: 0)
    )
    repository.record(
        sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        result: StudyResult(uniqueCardCount: 6, forgottenCount: 2)
    )

    let restored = UserDefaultsStatisticsRepository(defaults: defaults).statistics

    #expect(restored.completedLessonCount == 2)
    #expect(restored.studiedCardCount == 10)
    #expect(restored.forgottenCount == 2)
    #expect(restored.averageCardsPerLesson == 5)
    #expect(restored.lessonsWithoutForgettingPercentage == 50)
}

@MainActor
@Test func recordingTheSameSessionTwiceDoesNotChangeTotals() {
    let defaults = makeIsolatedDefaults()
    defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
    let repository = UserDefaultsStatisticsRepository(defaults: defaults)
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let result = StudyResult(uniqueCardCount: 3, forgottenCount: 1)

    repository.record(sessionID: sessionID, result: result)
    repository.record(sessionID: sessionID, result: result)

    #expect(repository.statistics.completedLessonCount == 1)
    #expect(repository.statistics.studiedCardCount == 3)
    #expect(repository.statistics.forgottenCount == 1)
}

private let defaultsSuiteName = "StatisticsFeatureTests.UserDefaultsStatisticsRepository"

private func makeIsolatedDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: defaultsSuiteName)!
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    return defaults
}
