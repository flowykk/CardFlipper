@testable import StatisticsFeature
import Testing

@Test func statisticsMetricsReplaceForgettingWithLibraryCardCount() {
    let statistics = StudyStatistics(
        completedLessonCount: 3,
        studiedCardCount: 12,
        forgottenCount: 4,
        lessonsWithoutForgettingCount: 1
    )

    let metrics = StatisticsMetric.makeMetrics(
        statistics: statistics,
        libraryCardCount: 7
    )

    #expect(metrics.map(\.titleKey) == [
        "statistics.lessons",
        "statistics.cards",
        "statistics.average",
        "statistics.libraryCards"
    ])
    #expect(metrics.last?.value == "7")
    #expect(!metrics.map(\.titleKey).contains("statistics.forgotten"))
    #expect(!metrics.map(\.titleKey).contains("statistics.withoutForgetting"))
}

@Test func libraryCardMetricShowsZeroForEmptyLibrary() {
    let metrics = StatisticsMetric.makeMetrics(
        statistics: StudyStatistics(),
        libraryCardCount: 0
    )

    #expect(metrics.last?.titleKey == "statistics.libraryCards")
    #expect(metrics.last?.value == "0")
}
