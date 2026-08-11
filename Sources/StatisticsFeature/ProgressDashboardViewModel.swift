import Foundation
import Observation

public struct ActivityCalendarDay: Identifiable, Equatable, Sendable {
    public let id: Int
    public let date: Date?
    public let dayNumber: Int?
    public let isToday: Bool
    public let isAchieved: Bool
}

@MainActor
@Observable
public final class ProgressDashboardViewModel {
    public private(set) var selectedMonth: Date
    public private(set) var todayProgress: DailyProgress
    public private(set) var days: [ActivityCalendarDay] = []
    public private(set) var weekdaySymbols: [String] = []
    public var isGoalEditorPresented = false

    private let progress: any DailyProgressRepository
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        progress: any DailyProgressRepository,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.progress = progress
        self.calendar = calendar
        self.now = now
        let today = now()
        selectedMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        todayProgress = progress.progress(for: today, calendar: calendar)
        rebuild()
    }

    public var goalMinutes: Int { todayProgress.goalSeconds / 60 }
    public var progressFraction: Double {
        guard todayProgress.goalSeconds > 0 else { return 0 }
        return min(1, Double(todayProgress.elapsedSeconds) / Double(todayProgress.goalSeconds))
    }
    public var canMoveToNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth),
              let current = calendar.dateInterval(of: .month, for: now())?.start else { return false }
        return next <= current
    }
    public var monthTitle: String {
        selectedMonth.formatted(.dateTime.month(.wide).year().locale(calendar.locale ?? .current))
    }

    public func refresh() {
        todayProgress = progress.progress(for: now(), calendar: calendar)
        rebuild()
    }

    public func setGoal(minutes: Int) {
        progress.setPreferredGoal(minutes: minutes, on: now(), calendar: calendar)
        refresh()
    }

    public func moveToPreviousMonth() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = month
        rebuild()
    }

    public func moveToNextMonth() {
        guard canMoveToNextMonth,
              let month = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        selectedMonth = month
        rebuild()
    }

    private func rebuild() {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        weekdaySymbols = Array(symbols[offset...] + symbols[..<offset])
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth),
              let first = calendar.dateInterval(of: .month, for: selectedMonth)?.start else {
            days = []
            return
        }
        let achieved = Set(progress.records(in: selectedMonth, calendar: calendar)
            .filter(\.goalAchieved)
            .map(\.day))
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells = (0..<leading).map {
            ActivityCalendarDay(id: $0, date: nil, dayNumber: nil, isToday: false, isAchieved: false)
        }
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
            cells.append(ActivityCalendarDay(
                id: cells.count,
                date: date,
                dayNumber: day,
                isToday: calendar.isDate(date, inSameDayAs: now()),
                isAchieved: achieved.contains(LocalDay(date: date, calendar: calendar))
            ))
        }
        days = cells
    }
}
