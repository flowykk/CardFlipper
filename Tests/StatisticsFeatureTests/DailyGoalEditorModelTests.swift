@testable import StatisticsFeature
import Testing

@MainActor
@Test func dailyGoalDraftSavesOnlyAfterConfirmation() {
    var savedMinutes: [Int] = []
    let model = DailyGoalEditorModel(goalMinutes: 15) {
        savedMinutes.append($0)
    }

    model.selectedMinutes = 30

    #expect(savedMinutes.isEmpty)

    model.confirm()

    #expect(savedMinutes == [30])
}

@MainActor
@Test func newDailyGoalDraftRestoresPersistedValueAndFullRange() {
    let abandoned = DailyGoalEditorModel(goalMinutes: 15) { _ in }
    abandoned.selectedMinutes = 30

    let reopened = DailyGoalEditorModel(goalMinutes: 15) { _ in }

    #expect(reopened.selectedMinutes == 15)
    #expect(reopened.minuteOptions == Array(1...240))
}
