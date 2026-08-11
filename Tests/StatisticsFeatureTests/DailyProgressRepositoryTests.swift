import Foundation
import StatisticsFeature
import Testing

@MainActor
@Test func dailyProgressDefaultsToFifteenMinutes() {
    let store = makeProgressStore()
    let progress = store.progress(for: date(2026, 8, 11, 12), calendar: calendar)

    #expect(store.preferredGoalSeconds == 900)
    #expect(progress.elapsedSeconds == 0)
    #expect(progress.goalSeconds == 900)
    #expect(!progress.goalAchieved)
}

@MainActor
@Test func intervalsAccumulateAndSplitAtMidnight() {
    let store = makeProgressStore()
    _ = store.recordActiveInterval(
        from: date(2026, 8, 11, 23, 59, 30),
        to: date(2026, 8, 12, 0, 1, 0),
        calendar: calendar
    )
    _ = store.recordActiveInterval(
        from: date(2026, 8, 12, 8),
        to: date(2026, 8, 12, 8, 2),
        calendar: calendar
    )

    #expect(store.progress(for: date(2026, 8, 11), calendar: calendar).elapsedSeconds == 30)
    #expect(store.progress(for: date(2026, 8, 12), calendar: calendar).elapsedSeconds == 180)
}

@MainActor
@Test func achievedDayRemainsAchievedWhenGoalIncreases() {
    let store = makeProgressStore()
    let today = date(2026, 8, 11)
    _ = store.recordActiveInterval(from: today, to: today.addingTimeInterval(900), calendar: calendar)

    store.setPreferredGoal(minutes: 30, on: today, calendar: calendar)

    let progress = store.progress(for: today, calendar: calendar)
    #expect(progress.goalSeconds == 1_800)
    #expect(progress.goalAchieved)
}

@MainActor
@Test func goalChangeDoesNotRecalculateHistory() {
    let store = makeProgressStore()
    let yesterday = date(2026, 8, 10)
    _ = store.recordActiveInterval(from: yesterday, to: yesterday.addingTimeInterval(120), calendar: calendar)

    store.setPreferredGoal(minutes: 30, on: date(2026, 8, 11), calendar: calendar)

    #expect(store.progress(for: yesterday, calendar: calendar).goalSeconds == 900)
    #expect(store.progress(for: date(2026, 8, 12), calendar: calendar).goalSeconds == 1_800)
}

@MainActor
@Test func dailyProgressPersistsAndCorruptPayloadFallsBackSafely() {
    let defaults = isolatedDefaults()
    let today = date(2026, 8, 11)
    let store = UserDefaultsDailyProgressRepository(defaults: defaults)
    _ = store.recordActiveInterval(from: today, to: today.addingTimeInterval(75), calendar: calendar)

    let restored = UserDefaultsDailyProgressRepository(defaults: defaults)
    #expect(restored.progress(for: today, calendar: calendar).elapsedSeconds == 75)

    defaults.set(Data("invalid".utf8), forKey: UserDefaultsDailyProgressRepository.defaultStorageKey)
    let recovered = UserDefaultsDailyProgressRepository(defaults: defaults)
    #expect(recovered.preferredGoalSeconds == 900)
    #expect(recovered.records(in: today, calendar: calendar).isEmpty)
}

private let calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(secondsFromGMT: 0)!
    return value
}()

private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0,
    _ second: Int = 0
) -> Date {
    calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second
    ))!
}

@MainActor
private func makeProgressStore() -> UserDefaultsDailyProgressRepository {
    UserDefaultsDailyProgressRepository(defaults: isolatedDefaults())
}

private func isolatedDefaults() -> UserDefaults {
    let name = "DailyProgressRepositoryTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
