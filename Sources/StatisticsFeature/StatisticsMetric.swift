import Foundation

struct StatisticsMetric: Equatable, Sendable {
    let titleKey: String
    let value: String
    let systemImage: String

    static func makeMetrics(
        statistics: StudyStatistics,
        libraryCardCount: Int
    ) -> [StatisticsMetric] {
        [
            StatisticsMetric(
                titleKey: "statistics.lessons",
                value: statistics.completedLessonCount.formatted(),
                systemImage: "graduationcap.fill"
            ),
            StatisticsMetric(
                titleKey: "statistics.cards",
                value: statistics.studiedCardCount.formatted(),
                systemImage: "rectangle.stack.fill"
            ),
            StatisticsMetric(
                titleKey: "statistics.average",
                value: statistics.averageCardsPerLesson.formatted(
                    .number.precision(.fractionLength(1))
                ),
                systemImage: "chart.bar.fill"
            ),
            StatisticsMetric(
                titleKey: "statistics.libraryCards",
                value: libraryCardCount.formatted(),
                systemImage: "books.vertical.fill"
            )
        ]
    }
}
