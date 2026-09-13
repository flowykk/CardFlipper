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

@MainActor
@Test func migratingOriginalUnversionedStorePreservesVocabularyAndSupportsHistory() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CardFlipperHistoryMigration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let storeURL = directory.appendingPathComponent("default.store")
    let originalCard: VocabularyCard
    let originalTag: Core.Tag

    do {
        let originalSchema = Schema([
            CardEntity.self,
            RussianMeaningEntity.self,
            EnglishVariantEntity.self,
            UsageExampleEntity.self,
            TagEntity.self,
        ])
        let configuration = ModelConfiguration(
            "OriginalUnversionedStore",
            schema: originalSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: originalSchema,
            configurations: [configuration]
        )
        let repositories = TestRepositories(container: container)
        originalTag = try await repositories.tags.create(name: "Работа & учёба")
        originalCard = .fixture(tag: originalTag, isLearned: true)
        try await repositories.cards.save(originalCard)
    }

    do {
        let configuration = ModelConfiguration(
            "OriginalUnversionedStore",
            schema: CardFlipperSchema.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: CardFlipperSchema.schema,
            migrationPlan: CardFlipperMigrationPlan.self,
            configurations: [configuration]
        )
        let repositories = TestRepositories(container: container)
        let history = SwiftDataStudyHistoryRepository(container: container)

        #expect(try await repositories.cards.fetchCards() == [originalCard])
        #expect(try await repositories.tags.fetchTags() == [originalTag])
        #expect(try history.insertIfNeeded(.fixture()))
        #expect(try history.fetchHistory() == [.fixture()])
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
