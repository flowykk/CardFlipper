import Foundation
import Observation

public enum ActivityCalendarState: Equatable, Sendable {
    case future
    case noActivity
    case activeBelowGoal
    case goalAchieved
}

public struct StudyTrendSummary: Equatable, Sendable {
    public let currentSevenDaySeconds: Int
    public let previousSevenDaySeconds: Int
    public let streakDays: Int

    public init(
        currentSevenDaySeconds: Int,
        previousSevenDaySeconds: Int,
        streakDays: Int
    ) {
        self.currentSevenDaySeconds = max(0, currentSevenDaySeconds)
        self.previousSevenDaySeconds = max(0, previousSevenDaySeconds)
        self.streakDays = max(0, streakDays)
    }

    public static let zero = StudyTrendSummary(
        currentSevenDaySeconds: 0,
        previousSevenDaySeconds: 0,
        streakDays: 0
    )

    public var deltaSeconds: Int { currentSevenDaySeconds - previousSevenDaySeconds }
}

public struct ActivityCalendarDay: Identifiable, Equatable, Sendable {
    public let id: Int
    public let date: Date?
    public let dayNumber: Int?
    public let isToday: Bool
    public let state: ActivityCalendarState

    public var isAchieved: Bool { state == .goalAchieved }
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
    public var trend: StudyTrendSummary { makeTrend() }

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
        let records = Dictionary(uniqueKeysWithValues: progress
            .records(in: selectedMonth, calendar: calendar)
            .map { ($0.day, $0) })
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells = (0..<leading).map {
            ActivityCalendarDay(
                id: $0,
                date: nil,
                dayNumber: nil,
                isToday: false,
                state: .noActivity
            )
        }
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
            let record = records[LocalDay(date: date, calendar: calendar)]
            let state: ActivityCalendarState
            if calendar.startOfDay(for: date) > calendar.startOfDay(for: now()) {
                state = .future
            } else if record?.goalAchieved == true {
                state = .goalAchieved
            } else if (record?.elapsedSeconds ?? 0) > 0 {
                state = .activeBelowGoal
            } else {
                state = .noActivity
            }
            cells.append(ActivityCalendarDay(
                id: cells.count,
                date: date,
                dayNumber: day,
                isToday: calendar.isDate(date, inSameDayAs: now()),
                state: state
            ))
        }
        days = cells
    }

    private func makeTrend() -> StudyTrendSummary {
        let today = calendar.startOfDay(for: now())
        let current = totalSeconds(fromDayOffset: -6, through: 0, relativeTo: today)
        let previous = totalSeconds(fromDayOffset: -13, through: -7, relativeTo: today)

        var streak = 0
        var offset = progress.progress(for: today, calendar: calendar).elapsedSeconds > 0 ? 0 : -1
        while let date = calendar.date(byAdding: .day, value: offset, to: today),
              progress.progress(for: date, calendar: calendar).elapsedSeconds > 0 {
            streak += 1
            offset -= 1
        }

        return StudyTrendSummary(
            currentSevenDaySeconds: current,
            previousSevenDaySeconds: previous,
            streakDays: streak
        )
    }

    private func totalSeconds(
        fromDayOffset start: Int,
        through end: Int,
        relativeTo today: Date
    ) -> Int {
        (start...end).reduce(into: 0) { total, offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return }
            total += progress.progress(for: date, calendar: calendar).elapsedSeconds
        }
    }
}
