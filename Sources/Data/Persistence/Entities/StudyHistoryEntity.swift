import Foundation
import SwiftData

@Model
final class StudyHistoryEntity {
    @Attribute(.unique) var sessionID: UUID
    var startedAt: Date
    var completedAt: Date
    var modeRawValue: String
    var directionRawValue: String
    var selectedTagNamesData: Data
    var plannedCardCount: Int
    var completedCardCount: Int
    var encounteredCardCount: Int
    var repeatedCardCount: Int
    var forgottenCount: Int
    var totalAssessmentCount: Int
    var elapsedSeconds: Int
    var difficultCardTitlesData: Data

    init(
        sessionID: UUID,
        startedAt: Date,
        completedAt: Date,
        modeRawValue: String,
        directionRawValue: String,
        selectedTagNamesData: Data,
        plannedCardCount: Int,
        completedCardCount: Int,
        encounteredCardCount: Int,
        repeatedCardCount: Int,
        forgottenCount: Int,
        totalAssessmentCount: Int,
        elapsedSeconds: Int,
        difficultCardTitlesData: Data
    ) {
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.modeRawValue = modeRawValue
        self.directionRawValue = directionRawValue
        self.selectedTagNamesData = selectedTagNamesData
        self.plannedCardCount = plannedCardCount
        self.completedCardCount = completedCardCount
        self.encounteredCardCount = encounteredCardCount
        self.repeatedCardCount = repeatedCardCount
        self.forgottenCount = forgottenCount
        self.totalAssessmentCount = totalAssessmentCount
        self.elapsedSeconds = elapsedSeconds
        self.difficultCardTitlesData = difficultCardTitlesData
    }
}
