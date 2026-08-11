import Foundation

public struct LocalDay: Codable, Hashable, Comparable, Sendable {
    public let era: Int
    public let year: Int
    public let month: Int
    public let day: Int

    public init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        era = components.era ?? 1
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.era, lhs.year, lhs.month, lhs.day) < (rhs.era, rhs.year, rhs.month, rhs.day)
    }
}

public struct DailyProgress: Codable, Equatable, Sendable {
    public let day: LocalDay
    public let elapsedSeconds: Int
    public let goalSeconds: Int
    public let goalAchieved: Bool

    public init(day: LocalDay, elapsedSeconds: Int, goalSeconds: Int, goalAchieved: Bool) {
        self.day = day
        self.elapsedSeconds = elapsedSeconds
        self.goalSeconds = goalSeconds
        self.goalAchieved = goalAchieved
    }
}
