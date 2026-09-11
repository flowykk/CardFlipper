@testable import StatisticsFeature
import Testing

@Test func statisticsMetricsExposeLearningOutcomesAndTrend() {
    let statistics = StudyStatistics(
        completedLessonCount: 3,
        studiedCardCount: 12,
        forgottenCount: 4,
        lessonsWithoutForgettingCount: 1,
        repeatedCardCount: 3,
        totalAssessmentCount: 16
    )

    let metrics = StatisticsMetric.makeMetrics(
        statistics: statistics,
        libraryCardCount: 7,
        trend: StudyTrendSummary(
            currentSevenDaySeconds: 900,
            previousSevenDaySeconds: 600,
            streakDays: 4
        )
    )

    #expect(metrics.map(\.titleKey) == [
        "statistics.lessons",
        "statistics.cards",
        "statistics.repeated",
        "statistics.recallRate",
        "statistics.streak",
        "statistics.sevenDayTime",
        "statistics.libraryCards"
    ])
    #expect(metrics.last?.value == "7")
    #expect(metrics.first { $0.titleKey == "statistics.recallRate" }?.value == "75%")
    #expect(metrics.first { $0.titleKey == "statistics.sevenDayTime" }?.detail == "+05:00")
}

@Test func libraryCardMetricShowsZeroForEmptyLibrary() {
    let metrics = StatisticsMetric.makeMetrics(
        statistics: StudyStatistics(),
        libraryCardCount: 0
    )

    #expect(metrics.last?.titleKey == "statistics.libraryCards")
    #expect(metrics.last?.value == "0")
}
