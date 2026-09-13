import Core
import Foundation
import StudyFeature

extension StudySessionSnapshot {
    /// Legacy snapshots contain completion/repetition IDs but no encounter or display metadata.
    /// Backfill only missing data, then persist it so subsequent library edits cannot rewrite it.
    func backfillingStudyMetadata(cards: [VocabularyCard], tags: [Tag]) -> Self {
        var encounteredIDs = encounteredCardIDs
            .union(completedCardIDs)
            .union(repeatedCardIDs)
        if mode == .writing, writingEvaluation != .unanswered || isRevealed,
           let currentID = queueCardIDs.first {
            encounteredIDs.insert(currentID)
        }
        encounteredIDs.formIntersection(originalCardIDs)

        let capturedIDs = Set(cardDisplaySnapshots.map(\.id))
        let originalIDs = Set(originalCardIDs)
        let missingDisplays = cards.filter {
            originalIDs.contains($0.id) && !capturedIDs.contains($0.id)
        }.map { StudyCardDisplaySnapshot(id: $0.id, title: studyCardDisplayTitle($0)) }
        let tagNames = selectedTagNames.isEmpty
            ? tags.filter { selectedTagIDs.contains($0.id) }.map(\.name).sorted()
            : selectedTagNames

        return Self(
            mode: mode,
            direction: direction,
            selectedTagIDs: selectedTagIDs,
            originalCardIDs: originalCardIDs,
            queueCardIDs: queueCardIDs,
            isShowingAnswer: isShowingAnswer,
            isRevealed: isRevealed,
            forgottenCount: forgottenCount,
            repeatedCardIDs: repeatedCardIDs,
            totalAssessmentCount: totalAssessmentCount,
            writingResponse: writingResponse,
            writingEvaluation: writingEvaluation,
            startedAt: startedAt,
            accumulatedDurationSeconds: accumulatedDurationSeconds,
            sessionID: sessionID,
            lastActivityAt: lastActivityAt,
            encounteredCardIDs: encounteredIDs,
            completedCardIDs: completedCardIDs,
            selectedTagNames: tagNames,
            cardDisplaySnapshots: cardDisplaySnapshots + missingDisplays,
            completedResult: completedResult,
            legacyCompletedStatisticsRecorded: legacyCompletedStatisticsRecorded
        )
    }
}
