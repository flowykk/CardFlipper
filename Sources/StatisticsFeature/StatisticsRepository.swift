import Core
import Foundation

@MainActor
public protocol StatisticsRepository: AnyObject {
    var statistics: StudyStatistics { get }

    func record(sessionID: UUID, result: StudyResult)
}

@MainActor
public final class UserDefaultsStatisticsRepository: StatisticsRepository {
    public private(set) var statistics: StudyStatistics

    private struct StoredStatistics: Codable {
        var completedLessonCount = 0
        var studiedCardCount = 0
        var forgottenCount = 0
        var lessonsWithoutForgettingCount = 0
        var recordedSessionIDs: Set<UUID> = []

        var value: StudyStatistics {
            StudyStatistics(
                completedLessonCount: completedLessonCount,
                studiedCardCount: studiedCardCount,
                forgottenCount: forgottenCount,
                lessonsWithoutForgettingCount: lessonsWithoutForgettingCount
            )
        }
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private var stored: StoredStatistics

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "statistics.completedStudySessions.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        stored = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode(StoredStatistics.self, from: $0) }
            ?? StoredStatistics()
        statistics = stored.value
    }

    public func record(sessionID: UUID, result: StudyResult) {
        guard stored.recordedSessionIDs.insert(sessionID).inserted else { return }

        stored.completedLessonCount += 1
        stored.studiedCardCount += result.uniqueCardCount
        stored.forgottenCount += result.forgottenCount
        if result.forgottenCount == 0 {
            stored.lessonsWithoutForgettingCount += 1
        }

        statistics = stored.value
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
