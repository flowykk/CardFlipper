import DesignSystem
import Foundation

struct StatisticsMetric: Equatable, Sendable {
    let titleKey: String
    let subtitleKey: String?
    let value: String
    let systemImage: String
    let detail: String?

    static func makeOverviewMetrics(
        libraryCardCount: Int,
        trend: StudyTrendSummary = .zero
    ) -> [StatisticsMetric] {
        [
            StatisticsMetric(
                titleKey: "statistics.streak",
                subtitleKey: nil,
                value: trend.streakDays.formatted(),
                systemImage: "flame.fill",
                detail: nil
            ),
            StatisticsMetric(
                titleKey: "statistics.sevenDayTime",
                subtitleKey: "statistics.sevenDayTime.subtitle",
                value: StudyDurationFormatter.string(seconds: trend.currentSevenDaySeconds),
                systemImage: "chart.line.uptrend.xyaxis",
                detail: deltaText(trend.deltaSeconds)
            ),
            StatisticsMetric(
                titleKey: "statistics.libraryCards",
                subtitleKey: nil,
                value: libraryCardCount.formatted(),
                systemImage: "books.vertical.fill",
                detail: nil
            )
        ]
    }

    static func makeModeSections(statistics: StudyStatistics) -> [StatisticsMetricSection] {
        [
            StatisticsMetricSection(
                titleKey: "statistics.section.flashcards",
                metrics: metrics(for: statistics.flashcards, writing: false)
            ),
            StatisticsMetricSection(
                titleKey: "statistics.section.writing",
                metrics: metrics(for: statistics.writing, writing: true)
            )
        ]
    }

    private static func metrics(
        for statistics: StudyModeStatistics,
        writing: Bool
    ) -> [StatisticsMetric] {
        [
            StatisticsMetric(
                titleKey: writing ? "statistics.writing.sessions" : "statistics.lessons",
                subtitleKey: nil,
                value: statistics.completedLessonCount.formatted(),
                systemImage: writing ? "pencil.line" : AppSymbol.study,
                detail: nil
            ),
            StatisticsMetric(
                titleKey: writing ? "statistics.writing.cards" : "statistics.cards",
                subtitleKey: writing ? "statistics.writing.cards.subtitle" : nil,
                value: statistics.studiedCardCount.formatted(),
                systemImage: writing ? "character.cursor.ibeam" : AppSymbol.library,
                detail: nil
            ),
            StatisticsMetric(
                titleKey: writing ? "statistics.writing.difficult" : "statistics.repeated",
                subtitleKey: nil,
                value: statistics.repeatedCardCount.formatted(),
                systemImage: AppSymbol.repeatedCards,
                detail: nil
            ),
            StatisticsMetric(
                titleKey: writing ? "statistics.writing.accuracy" : "statistics.recallRate",
                subtitleKey: writing
                    ? "statistics.writing.accuracy.subtitle"
                    : "statistics.recallRate.subtitle",
                value: "\(statistics.firstTryRecallPercentage)%",
                systemImage: "target",
                detail: nil
            )
        ]
    }

    private static func deltaText(_ seconds: Int) -> String {
        guard seconds != 0 else { return "±00:00" }
        return "\(seconds > 0 ? "+" : "−")\(StudyDurationFormatter.string(seconds: abs(seconds)))"
    }
}

struct StatisticsMetricSection: Equatable, Sendable {
    let titleKey: String
    let metrics: [StatisticsMetric]
}
