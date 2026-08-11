import Foundation

@MainActor
public final class UserDefaultsDailyProgressRepository: DailyProgressRepository {
    public static let defaultStorageKey = "statistics.dailyStudyProgress.v1"
    public private(set) var preferredGoalSeconds: Int

    private struct Payload: Codable {
        var preferredGoalSeconds: Int
        var records: [LocalDay: DailyProgress]
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private var records: [LocalDay: DailyProgress]

    public init(defaults: UserDefaults = .standard, storageKey: String = defaultStorageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let payload = try? JSONDecoder().decode(Payload.self, from: data),
           (60...14_400).contains(payload.preferredGoalSeconds),
           payload.records.values.allSatisfy({
               $0.elapsedSeconds >= 0 && (60...14_400).contains($0.goalSeconds)
           }) {
            preferredGoalSeconds = payload.preferredGoalSeconds
            records = payload.records
        } else {
            preferredGoalSeconds = 900
            records = [:]
        }
    }

    public func progress(for date: Date, calendar: Calendar) -> DailyProgress {
        let day = LocalDay(date: date, calendar: calendar)
        return records[day] ?? DailyProgress(
            day: day,
            elapsedSeconds: 0,
            goalSeconds: preferredGoalSeconds,
            goalAchieved: false
        )
    }

    public func records(in month: Date, calendar: Calendar) -> [DailyProgress] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return records.values
            .filter { progress in
                guard let date = calendar.date(from: DateComponents(
                    era: progress.day.era,
                    year: progress.day.year,
                    month: progress.day.month,
                    day: progress.day.day
                )) else { return false }
                return interval.contains(date)
            }
            .sorted { $0.day < $1.day }
    }

    @discardableResult
    public func recordActiveInterval(from start: Date, to end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        var cursor = start
        var total = 0

        while cursor < end {
            let startOfDay = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { break }
            let segmentEnd = min(end, nextDay)
            let seconds = max(0, Int(segmentEnd.timeIntervalSince(cursor).rounded(.down)))
            if seconds > 0 {
                add(seconds: seconds, on: cursor, calendar: calendar)
                total += seconds
            }
            cursor = segmentEnd
        }
        return total
    }

    public func setPreferredGoal(minutes: Int, on date: Date, calendar: Calendar) {
        let seconds = min(max(minutes, 1), 240) * 60
        preferredGoalSeconds = seconds
        let existing = progress(for: date, calendar: calendar)
        records[existing.day] = DailyProgress(
            day: existing.day,
            elapsedSeconds: existing.elapsedSeconds,
            goalSeconds: seconds,
            goalAchieved: existing.goalAchieved || existing.elapsedSeconds >= seconds
        )
        persist()
    }

    private func add(seconds: Int, on date: Date, calendar: Calendar) {
        let existing = progress(for: date, calendar: calendar)
        let elapsed = existing.elapsedSeconds + seconds
        records[existing.day] = DailyProgress(
            day: existing.day,
            elapsedSeconds: elapsed,
            goalSeconds: existing.goalSeconds,
            goalAchieved: existing.goalAchieved || elapsed >= existing.goalSeconds
        )
        persist()
    }

    private func persist() {
        let payload = Payload(preferredGoalSeconds: preferredGoalSeconds, records: records)
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
