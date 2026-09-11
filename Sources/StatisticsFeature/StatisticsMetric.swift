import DesignSystem
import Foundation

struct StatisticsMetric: Equatable, Sendable {
    let titleKey: String
    let value: String
    let systemImage: String
    let detail: String?

    static func makeMetrics(
        statistics: StudyStatistics,
        libraryCardCount: Int,
        trend: StudyTrendSummary = .zero
    ) -> [StatisticsMetric] {
        [
            StatisticsMetric(
                titleKey: "statistics.lessons",
                value: statistics.completedLessonCount.formatted(),
                systemImage: AppSymbol.study,
                detail: nil
            ),
            StatisticsMetric(
                titleKey: "statistics.cards",
                value: statistics.studiedCardCount.formatted(),
                systemImage: AppSymbol.library,
                detail: nil
            ),
            StatisticsMetric(
                titleKey: "statistics.repeated",
                value: statistics.repeatedCardCount.formatted(),
                systemImage: AppSymbol.repeatedCards,
                detail: nil
            ),
            StatisticsMetric(
                titleKey: "statistics.recallRate",
                value: "\(statistics.firstTryRecallPercentage)%",
                systemImage: "target",
                detail: nil
            ),
            StatisticsMetric(
                titleKey: "statistics.streak",
                value: trend.streakDays.formatted(),
                systemImage: "flame.fill",
                detail: nil
            ),
            StatisticsMetric(
                titleKey: "statistics.sevenDayTime",
                value: StudyDurationFormatter.string(seconds: trend.currentSevenDaySeconds),
                systemImage: "chart.line.uptrend.xyaxis",
                detail: deltaText(trend.deltaSeconds)
            ),
            StatisticsMetric(
                titleKey: "statistics.libraryCards",
                value: libraryCardCount.formatted(),
                systemImage: "books.vertical.fill",
                detail: nil
            )
        ]
    }

    private static func deltaText(_ seconds: Int) -> String {
        guard seconds != 0 else { return "±00:00" }
        return "\(seconds > 0 ? "+" : "−")\(StudyDurationFormatter.string(seconds: abs(seconds)))"
    }
}
