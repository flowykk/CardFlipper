import Core
import Foundation

@MainActor
final class StudyHistoryRepositoryFake: StudyHistoryRepository {
    var fetchedEntries: [StudyHistoryEntry]
    var fetchError: (any Error)?

    init(
        fetchedEntries: [StudyHistoryEntry] = [],
        fetchError: (any Error)? = nil
    ) {
        self.fetchedEntries = fetchedEntries
        self.fetchError = fetchError
    }

    func fetchHistory() throws -> [StudyHistoryEntry] {
        if let fetchError { throw fetchError }
        return fetchedEntries
    }

    func insertIfNeeded(_ entry: StudyHistoryEntry) throws -> Bool { false }
}

enum HistoryTestError: Error {
    case fetch
}

extension StudyHistoryEntry {
    static func fixture(
        id: UUID = UUID(),
        completedAt: Date,
        mode: StudyMode = .flashcards,
        selectedTagNames: [String] = ["Work"],
        difficultCardTitles: [String] = ["book — книга"]
    ) -> Self {
        StudyHistoryEntry(
            id: id,
            startedAt: completedAt.addingTimeInterval(-300),
            completedAt: completedAt,
            mode: mode,
            direction: .englishToRussian,
            selectedTagNames: selectedTagNames,
            plannedCardCount: 10,
            completedCardCount: 8,
            encounteredCardCount: 8,
            repeatedCardCount: 2,
            forgottenCount: 1,
            totalAssessmentCount: 9,
            elapsedSeconds: 300,
            difficultCardTitles: difficultCardTitles
        )
    }
}
