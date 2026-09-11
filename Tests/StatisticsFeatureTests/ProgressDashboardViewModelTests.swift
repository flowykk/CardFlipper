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
@Test func calendarDistinguishesFutureEmptyActiveAndAchievedDays() {
    let fixture = DashboardFixture()
    let yesterday = fixture.calendar.date(byAdding: .day, value: -1, to: fixture.today)!
    let twoDaysAgo = fixture.calendar.date(byAdding: .day, value: -2, to: fixture.today)!
    _ = fixture.store.recordActiveInterval(
        from: yesterday,
        to: yesterday.addingTimeInterval(120),
        calendar: fixture.calendar
    )
    _ = fixture.store.recordActiveInterval(
        from: twoDaysAgo,
        to: twoDaysAgo.addingTimeInterval(900),
        calendar: fixture.calendar
    )
    let model = ProgressDashboardViewModel(
        progress: fixture.store,
        calendar: fixture.calendar,
        now: { fixture.today }
    )

    #expect(model.days.first { $0.dayNumber == 9 }?.state == .goalAchieved)
    #expect(model.days.first { $0.dayNumber == 10 }?.state == .activeBelowGoal)
    #expect(model.days.first { $0.dayNumber == 11 }?.state == .noActivity)
    #expect(model.days.first { $0.dayNumber == 12 }?.state == .future)
    #expect(model.days.first { $0.dayNumber == 11 }?.isToday == true)
}

@MainActor
@Test func sevenDayTrendAndStreakAggregateAcrossMonthBoundary() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
    let store = UserDefaultsDailyProgressRepository(
        defaults: UserDefaults(suiteName: "ProgressTrendTests.\(UUID().uuidString)")!
    )
    for offset in [-2, -1, 0] {
        let day = calendar.date(byAdding: .day, value: offset, to: today)!
        _ = store.recordActiveInterval(
            from: day,
            to: day.addingTimeInterval(300),
            calendar: calendar
        )
    }
    let previousWindow = calendar.date(byAdding: .day, value: -8, to: today)!
    _ = store.recordActiveInterval(
        from: previousWindow,
        to: previousWindow.addingTimeInterval(120),
        calendar: calendar
    )

    let model = ProgressDashboardViewModel(
        progress: store,
        calendar: calendar,
        now: { today }
    )

    #expect(model.trend == StudyTrendSummary(
        currentSevenDaySeconds: 900,
        previousSevenDaySeconds: 120,
        streakDays: 3
    ))
    #expect(model.trend.deltaSeconds == 780)
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
