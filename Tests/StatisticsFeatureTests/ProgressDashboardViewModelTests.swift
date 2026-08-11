import Foundation
import StatisticsFeature
import Testing

@MainActor
@Test func calendarBuildsCompleteMonthAndDisablesFutureNavigation() {
    let fixture = DashboardFixture()
    let model = ProgressDashboardViewModel(
        progress: fixture.store,
        calendar: fixture.calendar,
        now: { fixture.today }
    )

    #expect(model.days.compactMap(\.date).count == 31)
    #expect(!model.canMoveToNextMonth)

    model.moveToPreviousMonth()
    #expect(model.days.compactMap(\.date).count == 31)
    #expect(model.canMoveToNextMonth)
}

@MainActor
@Test func changingGoalUpdatesTodayWithoutRemovingCompletion() {
    let fixture = DashboardFixture()
    _ = fixture.store.recordActiveInterval(
        from: fixture.today,
        to: fixture.today.addingTimeInterval(900),
        calendar: fixture.calendar
    )
    let model = ProgressDashboardViewModel(
        progress: fixture.store,
        calendar: fixture.calendar,
        now: { fixture.today }
    )

    model.setGoal(minutes: 30)

    #expect(model.goalMinutes == 30)
    #expect(model.todayProgress.goalAchieved)
    #expect(model.progressFraction == 0.5)
}

@MainActor
private struct DashboardFixture {
    let calendar: Calendar
    let today: Date
    let store: UserDefaultsDailyProgressRepository

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        self.calendar = calendar
        today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 11, hour: 12))!
        store = UserDefaultsDailyProgressRepository(
            defaults: UserDefaults(suiteName: "ProgressDashboardTests.\(UUID().uuidString)")!
        )
    }
}
