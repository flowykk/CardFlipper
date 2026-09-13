import Foundation
import SwiftData
import Testing
@testable import Core
@testable import Data

@MainActor
@Test func studyHistoryFetchesNewestFirstAndRoundTripsImmutableArrays() throws {
    let repository = SwiftDataStudyHistoryRepository(
        container: try ModelContainerFactory.makeInMemory()
    )
    let newest = StudyHistoryEntry.fixture(
        completedAt: Date(timeIntervalSince1970: 5_000)
    )
    let oldest = StudyHistoryEntry.fixture(
        id: TestIDs.secondStudySession,
        completedAt: Date(timeIntervalSince1970: 3_000),
        selectedTagNames: ["Фразовые глаголы?!", "Travel / отдых"],
        difficultCardTitles: ["to put up with — мириться", "don't / doesn't"]
    )

    #expect(try repository.insertIfNeeded(newest))
    #expect(try repository.insertIfNeeded(oldest))

    #expect(try repository.fetchHistory() == [newest, oldest])
}

@MainActor
@Test func studyHistoryInsertIsIdempotentBySessionID() throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataStudyHistoryRepository(container: container)
    let original = StudyHistoryEntry.fixture()
    let duplicate = StudyHistoryEntry.fixture(
        completedAt: Date(timeIntervalSince1970: 9_000),
        selectedTagNames: ["Different"],
        difficultCardTitles: ["Replacement"]
    )

    #expect(try repository.insertIfNeeded(original))
    #expect(try !repository.insertIfNeeded(duplicate))

    #expect(try repository.fetchHistory() == [original])
    #expect(try container.mainContext.fetchCount(FetchDescriptor<StudyHistoryEntity>()) == 1)
}

@MainActor
@Test func studyHistoryMappingThrowsTypedErrorForMalformedTagNames() throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataStudyHistoryRepository(container: container)
    let entity = historyEntity(selectedTagNamesData: Data("not-json".utf8))
    container.mainContext.insert(entity)
    try container.mainContext.save()

    do {
        _ = try repository.fetchHistory()
        Issue.record("Expected malformed history data to throw")
    } catch let error as SwiftDataStudyHistoryRepositoryError {
        #expect(error == .invalidSelectedTagNames(sessionID: TestIDs.studySession))
    }
}

@MainActor
@Test func studyHistoryMappingThrowsTypedErrorForMalformedDifficultCardTitles() throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataStudyHistoryRepository(container: container)
    let entity = historyEntity(difficultCardTitlesData: Data("not-json".utf8))
    container.mainContext.insert(entity)
    try container.mainContext.save()

    do {
        _ = try repository.fetchHistory()
        Issue.record("Expected malformed history data to throw")
    } catch let error as SwiftDataStudyHistoryRepositoryError {
        #expect(error == .invalidDifficultCardTitles(sessionID: TestIDs.studySession))
    }
}

private func historyEntity(
    selectedTagNamesData: Data = Data(#"["Work"]"#.utf8),
    difficultCardTitlesData: Data = Data(#"["well-being?"]"#.utf8)
) -> StudyHistoryEntity {
    StudyHistoryEntity(
        sessionID: TestIDs.studySession,
        startedAt: Date(timeIntervalSince1970: 3_880),
        completedAt: Date(timeIntervalSince1970: 4_000),
        modeRawValue: StudyMode.writing.rawValue,
        directionRawValue: StudyDirection.russianToEnglish.rawValue,
        selectedTagNamesData: selectedTagNamesData,
        plannedCardCount: 12,
        completedCardCount: 8,
        encounteredCardCount: 10,
        repeatedCardCount: 2,
        forgottenCount: 3,
        totalAssessmentCount: 15,
        elapsedSeconds: 120,
        difficultCardTitlesData: difficultCardTitlesData
    )
}
