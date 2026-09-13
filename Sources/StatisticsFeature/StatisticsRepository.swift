import Core
import Foundation

@MainActor
public protocol StatisticsRepository: AnyObject {
    var statistics: StudyStatistics { get }

    func record(sessionID: UUID, mode: StudyMode, result: StudyResult)
}

@MainActor
public final class UserDefaultsStatisticsRepository: StatisticsRepository {
    public private(set) var statistics: StudyStatistics

    private struct StoredStatistics: Codable {
        var completedLessonCount = 0
        var studiedCardCount = 0
        var encounteredCardCount: Int?
        var forgottenCount = 0
        var lessonsWithoutForgettingCount = 0
        var repeatedCardCount: Int?
        var totalAssessmentCount: Int?
        var writingCompletedLessonCount: Int?
        var writingStudiedCardCount: Int?
        var writingEncounteredCardCount: Int?
        var writingForgottenCount: Int?
        var writingLessonsWithoutForgettingCount: Int?
        var writingRepeatedCardCount: Int?
        var writingTotalAssessmentCount: Int?
        var recordedSessionIDs: Set<UUID> = []

        var value: StudyStatistics {
            let overall = StudyModeStatistics(
                completedLessonCount: completedLessonCount,
                studiedCardCount: studiedCardCount,
                encounteredCardCount: encounteredCardCount ?? studiedCardCount,
                forgottenCount: forgottenCount,
                lessonsWithoutForgettingCount: lessonsWithoutForgettingCount,
                repeatedCardCount: repeatedCardCount ?? 0,
                totalAssessmentCount: totalAssessmentCount ?? studiedCardCount + forgottenCount
            )
            let writing = StudyModeStatistics(
                completedLessonCount: writingCompletedLessonCount ?? 0,
                studiedCardCount: writingStudiedCardCount ?? 0,
                encounteredCardCount: writingEncounteredCardCount
                    ?? writingStudiedCardCount
                    ?? 0,
                forgottenCount: writingForgottenCount ?? 0,
                lessonsWithoutForgettingCount: writingLessonsWithoutForgettingCount ?? 0,
                repeatedCardCount: writingRepeatedCardCount ?? 0,
                totalAssessmentCount: writingTotalAssessmentCount ?? 0
            )
            return StudyStatistics(
                flashcards: overall.subtracting(writing),
                writing: writing
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

    public func record(sessionID: UUID, mode: StudyMode, result: StudyResult) {
        guard stored.recordedSessionIDs.insert(sessionID).inserted else { return }

        stored.completedLessonCount += 1
        stored.encounteredCardCount = (stored.encounteredCardCount ?? stored.studiedCardCount)
            + result.encounteredCardCount
        stored.studiedCardCount += result.completedCardCount
        stored.forgottenCount += result.forgottenCount
        stored.repeatedCardCount = (stored.repeatedCardCount ?? 0) + result.repeatedCardCount
        stored.totalAssessmentCount = (stored.totalAssessmentCount ?? 0) + result.totalAssessmentCount
        if result.forgottenCount == 0 {
            stored.lessonsWithoutForgettingCount += 1
        }
        if mode == .writing {
            stored.writingCompletedLessonCount = (stored.writingCompletedLessonCount ?? 0) + 1
            stored.writingEncounteredCardCount = (stored.writingEncounteredCardCount
                ?? stored.writingStudiedCardCount
                ?? 0) + result.encounteredCardCount
            stored.writingStudiedCardCount = (stored.writingStudiedCardCount ?? 0)
                + result.completedCardCount
            stored.writingForgottenCount = (stored.writingForgottenCount ?? 0)
                + result.forgottenCount
            stored.writingRepeatedCardCount = (stored.writingRepeatedCardCount ?? 0)
                + result.repeatedCardCount
            stored.writingTotalAssessmentCount = (stored.writingTotalAssessmentCount ?? 0)
                + result.totalAssessmentCount
            if result.forgottenCount == 0 {
                stored.writingLessonsWithoutForgettingCount =
                    (stored.writingLessonsWithoutForgettingCount ?? 0) + 1
            }
        }

        statistics = stored.value
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
