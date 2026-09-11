import Foundation

public struct StudyStatistics: Equatable, Sendable {
    public let completedLessonCount: Int
    public let studiedCardCount: Int
    public let forgottenCount: Int
    public let lessonsWithoutForgettingCount: Int
    public let repeatedCardCount: Int
    public let totalAssessmentCount: Int

    public init(
        completedLessonCount: Int = 0,
        studiedCardCount: Int = 0,
        forgottenCount: Int = 0,
        lessonsWithoutForgettingCount: Int = 0,
        repeatedCardCount: Int = 0,
        totalAssessmentCount: Int = 0
    ) {
        self.completedLessonCount = completedLessonCount
        self.studiedCardCount = studiedCardCount
        self.forgottenCount = forgottenCount
        self.lessonsWithoutForgettingCount = lessonsWithoutForgettingCount
        self.repeatedCardCount = repeatedCardCount
        self.totalAssessmentCount = totalAssessmentCount
    }

    public var averageCardsPerLesson: Double {
        guard completedLessonCount > 0 else { return 0 }
        return Double(studiedCardCount) / Double(completedLessonCount)
    }

    public var lessonsWithoutForgettingPercentage: Int {
        guard completedLessonCount > 0 else { return 0 }
        return Int(
            (Double(lessonsWithoutForgettingCount) / Double(completedLessonCount) * 100).rounded()
        )
    }

    public var firstTryRecallPercentage: Int {
        guard studiedCardCount > 0 else { return 0 }
        return Int(
            (Double(studiedCardCount - repeatedCardCount) / Double(studiedCardCount) * 100)
                .rounded()
        )
    }
}
