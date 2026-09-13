import Foundation

public struct StudyModeStatistics: Equatable, Sendable {
    public static let zero = StudyModeStatistics()

    public let completedLessonCount: Int
    public let studiedCardCount: Int
    public let encounteredCardCount: Int
    public let forgottenCount: Int
    public let lessonsWithoutForgettingCount: Int
    public let repeatedCardCount: Int
    public let totalAssessmentCount: Int

    public init(
        completedLessonCount: Int = 0,
        studiedCardCount: Int = 0,
        encounteredCardCount: Int? = nil,
        forgottenCount: Int = 0,
        lessonsWithoutForgettingCount: Int = 0,
        repeatedCardCount: Int = 0,
        totalAssessmentCount: Int = 0
    ) {
        self.completedLessonCount = max(0, completedLessonCount)
        self.studiedCardCount = max(0, studiedCardCount)
        self.encounteredCardCount = max(0, encounteredCardCount ?? studiedCardCount)
        self.forgottenCount = max(0, forgottenCount)
        self.lessonsWithoutForgettingCount = max(0, lessonsWithoutForgettingCount)
        self.repeatedCardCount = max(0, repeatedCardCount)
        self.totalAssessmentCount = max(0, totalAssessmentCount)
    }

    public var firstTryRecallPercentage: Int {
        guard encounteredCardCount > 0 else { return 0 }
        let recalled = max(0, encounteredCardCount - repeatedCardCount)
        return Int((Double(recalled) / Double(encounteredCardCount) * 100).rounded())
    }

    func adding(_ other: Self) -> Self {
        StudyModeStatistics(
            completedLessonCount: completedLessonCount + other.completedLessonCount,
            studiedCardCount: studiedCardCount + other.studiedCardCount,
            encounteredCardCount: encounteredCardCount + other.encounteredCardCount,
            forgottenCount: forgottenCount + other.forgottenCount,
            lessonsWithoutForgettingCount: lessonsWithoutForgettingCount
                + other.lessonsWithoutForgettingCount,
            repeatedCardCount: repeatedCardCount + other.repeatedCardCount,
            totalAssessmentCount: totalAssessmentCount + other.totalAssessmentCount
        )
    }

    func subtracting(_ other: Self) -> Self {
        StudyModeStatistics(
            completedLessonCount: completedLessonCount - other.completedLessonCount,
            studiedCardCount: studiedCardCount - other.studiedCardCount,
            encounteredCardCount: encounteredCardCount - other.encounteredCardCount,
            forgottenCount: forgottenCount - other.forgottenCount,
            lessonsWithoutForgettingCount: lessonsWithoutForgettingCount
                - other.lessonsWithoutForgettingCount,
            repeatedCardCount: repeatedCardCount - other.repeatedCardCount,
            totalAssessmentCount: totalAssessmentCount - other.totalAssessmentCount
        )
    }
}

public struct StudyStatistics: Equatable, Sendable {
    public let flashcards: StudyModeStatistics
    public let writing: StudyModeStatistics

    public var completedLessonCount: Int { overall.completedLessonCount }
    public var studiedCardCount: Int { overall.studiedCardCount }
    public var encounteredCardCount: Int { overall.encounteredCardCount }
    public var forgottenCount: Int { overall.forgottenCount }
    public var lessonsWithoutForgettingCount: Int { overall.lessonsWithoutForgettingCount }
    public var repeatedCardCount: Int { overall.repeatedCardCount }
    public var totalAssessmentCount: Int { overall.totalAssessmentCount }

    private var overall: StudyModeStatistics { flashcards.adding(writing) }

    public init(
        completedLessonCount: Int = 0,
        studiedCardCount: Int = 0,
        encounteredCardCount: Int? = nil,
        forgottenCount: Int = 0,
        lessonsWithoutForgettingCount: Int = 0,
        repeatedCardCount: Int = 0,
        totalAssessmentCount: Int = 0
    ) {
        flashcards = StudyModeStatistics(
            completedLessonCount: completedLessonCount,
            studiedCardCount: studiedCardCount,
            encounteredCardCount: encounteredCardCount,
            forgottenCount: forgottenCount,
            lessonsWithoutForgettingCount: lessonsWithoutForgettingCount,
            repeatedCardCount: repeatedCardCount,
            totalAssessmentCount: totalAssessmentCount
        )
        writing = .zero
    }

    public init(
        flashcards: StudyModeStatistics,
        writing: StudyModeStatistics
    ) {
        self.flashcards = flashcards
        self.writing = writing
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
        overall.firstTryRecallPercentage
    }
}
