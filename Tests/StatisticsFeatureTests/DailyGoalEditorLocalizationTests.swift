import Foundation
@testable import StatisticsFeature
import Testing

@Test func dailyGoalEditorTitleUsesStatisticsFeatureLocalization() {
    #expect(DailyGoalEditorCopy.title(locale: Locale(identifier: "en")) == "Daily Goal")
    #expect(DailyGoalEditorCopy.title(locale: Locale(identifier: "ru")) == "Дневная цель")
}
