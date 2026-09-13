@testable import StatisticsFeature
import Testing

@Test func firstTryRecallUsesEncounteredCardsForPartialGames() {
    let statistics = StudyStatistics(
        flashcards: StudyModeStatistics(
            studiedCardCount: 3,
            encounteredCardCount: 4,
            repeatedCardCount: 1
        ),
        writing: .zero
    )

    #expect(statistics.flashcards.firstTryRecallPercentage == 75)
    #expect(statistics.firstTryRecallPercentage == 75)
}

@Test func statisticsMetricsAreSeparatedByStudyMode() {
    let statistics = StudyStatistics(
        flashcards: StudyModeStatistics(
            completedLessonCount: 3,
            studiedCardCount: 12,
            forgottenCount: 4,
            lessonsWithoutForgettingCount: 1,
            repeatedCardCount: 3,
            totalAssessmentCount: 16
        ),
        writing: StudyModeStatistics(
            completedLessonCount: 2,
            studiedCardCount: 8,
            forgottenCount: 2,
            lessonsWithoutForgettingCount: 1,
            repeatedCardCount: 2,
            totalAssessmentCount: 10
        )
    )

    let sections = StatisticsMetric.makeModeSections(statistics: statistics)

    #expect(sections.map(\.titleKey) == [
        "statistics.section.flashcards",
        "statistics.section.writing"
    ])
    #expect(sections[0].metrics.map(\.titleKey) == [
        "statistics.lessons",
        "statistics.cards",
        "statistics.repeated",
        "statistics.recallRate"
    ])
    #expect(sections[0].metrics.map(\.value) == ["3", "12", "3", "75%"])
    #expect(sections[1].metrics.map(\.titleKey) == [
        "statistics.writing.sessions",
        "statistics.writing.cards",
        "statistics.writing.difficult",
        "statistics.writing.accuracy"
    ])
    #expect(sections[1].metrics.map(\.value) == ["2", "8", "2", "75%"])
    #expect(sections[1].metrics.last?.subtitleKey == "statistics.writing.accuracy.subtitle")
}

@Test func overviewMetricsExposeTrendAndLibraryCount() {
    let metrics = StatisticsMetric.makeOverviewMetrics(
        libraryCardCount: 7,
        trend: StudyTrendSummary(
            currentSevenDaySeconds: 900,
            previousSevenDaySeconds: 600,
            streakDays: 4
        )
    )

    #expect(metrics.map(\.titleKey) == [
        "statistics.streak",
        "statistics.sevenDayTime",
        "statistics.libraryCards"
    ])
    #expect(metrics.last?.value == "7")
    #expect(metrics.first { $0.titleKey == "statistics.sevenDayTime" }?.detail == "+05:00")
}

@Test func libraryCardMetricShowsZeroForEmptyLibrary() {
    let metrics = StatisticsMetric.makeOverviewMetrics(
        libraryCardCount: 0
    )

    #expect(metrics.last?.titleKey == "statistics.libraryCards")
    #expect(metrics.last?.value == "0")
}
