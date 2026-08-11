import Foundation

@MainActor
public protocol DailyProgressRepository: AnyObject {
    var preferredGoalSeconds: Int { get }

    func progress(for date: Date, calendar: Calendar) -> DailyProgress
    func records(in month: Date, calendar: Calendar) -> [DailyProgress]

    @discardableResult
    func recordActiveInterval(from start: Date, to end: Date, calendar: Calendar) -> Int

    func setPreferredGoal(minutes: Int, on date: Date, calendar: Calendar)
}
