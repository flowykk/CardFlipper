import Core
import Foundation
import StatisticsFeature

@MainActor
final class StudyHistoryFinalizer {
    private let history: any StudyHistoryRepository
    private let statistics: any StatisticsRepository
    private let sessionStore: any StudySessionStore

    init(history: any StudyHistoryRepository, statistics: any StatisticsRepository, sessionStore: any StudySessionStore) {
        self.history = history
        self.statistics = statistics
        self.sessionStore = sessionStore
    }

    func finalize(_ snapshot: StudySessionSnapshot, completedAt: Date) throws -> StudyHistoryEntry {
        let result = StudyResult(finalizing: snapshot)
        let entry = StudyHistoryEntry(finalizing: snapshot, result: result, completedAt: completedAt)
        _ = try history.insertIfNeeded(entry)
        statistics.record(sessionID: snapshot.sessionID, mode: snapshot.mode, result: result)
        sessionStore.clear()
        return entry
    }
}

extension StudyResult {
    init(finalizing snapshot: StudySessionSnapshot) {
        if let completedResult = snapshot.completedResult {
            self = completedResult
        } else {
            self.init(
                plannedCardCount: snapshot.originalCardIDs.count,
                completedCardCount: Set(snapshot.originalCardIDs)
                    .subtracting(snapshot.queueCardIDs)
                    .intersection(snapshot.completedCardIDs).count,
                encounteredCardIDs: snapshot.encounteredCardIDs,
                repeatedCardIDs: snapshot.repeatedCardIDs,
                totalAssessmentCount: snapshot.totalAssessmentCount,
                elapsedSeconds: snapshot.accumulatedDurationSeconds,
                forgottenCount: snapshot.forgottenCount
            )
        }
    }
}

/// Prevents retained result views from restoring a snapshot after finalization.
@MainActor
final class StudySessionWriteGate: StudySessionStore {
    private let store: any StudySessionStore
    private let allowsWriting: () -> Bool

    init(store: any StudySessionStore, allowsWriting: @escaping () -> Bool) {
        self.store = store
        self.allowsWriting = allowsWriting
    }

    func load() -> StudySessionSnapshot? { store.load() }
    func save(_ snapshot: StudySessionSnapshot) {
        guard allowsWriting() else { return }
        store.save(snapshot)
    }
    func clear() {
        guard allowsWriting() else { return }
        store.clear()
    }
}

extension StudyHistoryEntry {
    init(finalizing snapshot: StudySessionSnapshot, result: StudyResult, completedAt: Date) {
        let difficultIDs = Set(result.repeatedCardIDs)
        self.init(
            id: snapshot.sessionID,
            startedAt: snapshot.startedAt,
            completedAt: completedAt,
            mode: snapshot.mode,
            direction: snapshot.direction,
            selectedTagNames: snapshot.selectedTagNames,
            plannedCardCount: result.plannedCardCount,
            completedCardCount: result.completedCardCount,
            encounteredCardCount: result.encounteredCardCount,
            repeatedCardCount: result.repeatedCardCount,
            forgottenCount: result.forgottenCount,
            totalAssessmentCount: result.totalAssessmentCount,
            elapsedSeconds: result.elapsedSeconds,
            difficultCardTitles: snapshot.cardDisplaySnapshots
                .filter { difficultIDs.contains($0.id) }.map(\.title)
        )
    }
}
