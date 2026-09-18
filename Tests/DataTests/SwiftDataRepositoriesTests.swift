import Foundation
import SwiftData
import Testing
@testable import Core
@testable import Data

private enum TestRepositoryError: Error {
    case forcedFailure
}

@MainActor
@Test func savingAndFetchingPreservesOrderedValuesAndTags() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let tagRepository = SwiftDataTagRepository(container: container)
    let cardRepository = SwiftDataCardRepository(container: container)
    let tag = try await tagRepository.create(name: "Work")
    let card = VocabularyCard.fixture(tag: tag)

    try await cardRepository.save(card)
    let fetched = try await cardRepository.fetchCards()

    #expect(fetched == [card])
}

@MainActor
@Test func cardImportCommitsEditedCardsInOneBatch() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let importer = SwiftDataCardImportRepository(container: container)
    let cards = SwiftDataCardRepository(container: container)
    let imported = VocabularyCard.fixture()

    let result = try await importer.importCards([imported])

    #expect(result.addedCount == 1)
    #expect(try await cards.fetchCards() == [imported])
}

@MainActor
@Test func cardImportRollsBackAllPreparedChangesWhenCommitFails() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let cards = SwiftDataCardRepository(container: container)
    let original = VocabularyCard.fixture()
    try await cards.save(original)
    let imported = VocabularyCard.singleValueFixture(
        id: TestIDs.secondCard,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "экзамен",
        english: "exam",
        updatedAt: TestDates.updated
    )
    let importer = SwiftDataCardImportRepository(container: container) {
        throw TestRepositoryError.forcedFailure
    }

    await #expect(throws: TestRepositoryError.forcedFailure) {
        try await importer.importCards([imported])
    }
    #expect(try await cards.fetchCards() == [original])
}

@MainActor
@Test func cardImportRejectsAnIDCollisionWithTheExistingLibrary() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let cards = SwiftDataCardRepository(container: container)
    let original = VocabularyCard.fixture()
    try await cards.save(original)
    let conflicting = VocabularyCard.singleValueFixture(
        id: original.id,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "экзамен",
        english: "exam",
        updatedAt: TestDates.updated
    )
    let importer = SwiftDataCardImportRepository(container: container)

    await #expect(throws: CardImportValidationError.duplicateCardID(original.id)) {
        try await importer.importCards([conflicting])
    }
    #expect(try await cards.fetchCards() == [original])
}

@MainActor
@Test func cardImportReplacesAnEditedPreviewCardExactly() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let cards = SwiftDataCardRepository(container: container)
    let original = VocabularyCard.fixture()
    try await cards.save(original)
    let replacement = VocabularyCard.singleValueFixture(
        id: original.id,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "полностью новое значение",
        english: "replacement",
        updatedAt: TestDates.updated
    )
    let importer = SwiftDataCardImportRepository(container: container)

    let result = try await importer.importCards(
        [replacement],
        replacingCardIDs: [original.id]
    )

    #expect(result.addedCount == 0)
    #expect(result.mergedCount == 1)
    #expect(result.affectedCardIDs == [original.id])
    #expect(try await cards.fetchCards() == [replacement])
}

@MainActor
@Test func cardImportAddsReplacementWhoseTargetWasDeleted() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let cards = SwiftDataCardRepository(container: container)
    let imported = VocabularyCard.fixture()
    let importer = SwiftDataCardImportRepository(container: container)

    let result = try await importer.importCards(
        [imported],
        replacingCardIDs: [imported.id]
    )

    #expect(result.addedCount == 1)
    #expect(result.mergedCount == 0)
    #expect(result.affectedCardIDs == [imported.id])
    #expect(try await cards.fetchCards() == [imported])
}

@MainActor
@Test func addingTagsUpdatesOnlySelectedCardsAndDoesNotDuplicateExistingTags() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let tags = SwiftDataTagRepository(container: container)
    let cards = SwiftDataCardRepository(container: container)
    let work = try await tags.create(name: "Work")
    let exam = try await tags.create(name: "Exam")
    let first = VocabularyCard.fixture(tag: work)
    let second = VocabularyCard.singleValueFixture(
        id: TestIDs.secondCard,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "экзамен",
        english: "exam",
        updatedAt: TestDates.updated
    )
    try await cards.save(first)
    try await cards.save(second)

    try await cards.addTags(ids: [work.id, exam.id], toCardIDs: [second.id])

    let fetched = try await cards.fetchCards()
    let secondTagIDs = Set(fetched.first(where: { $0.id == second.id })?.tags.map(\.id) ?? [])
    #expect(fetched.first(where: { $0.id == first.id })?.tags == [work])
    #expect(secondTagIDs == Set([work.id, exam.id]))
}

@MainActor
@Test func savingAndFetchingPreservesLearnedState() async throws {
    let repository = SwiftDataCardRepository(
        container: try ModelContainerFactory.makeInMemory()
    )
    let card = VocabularyCard.fixture(isLearned: true)

    try await repository.save(card)

    #expect(try await repository.fetchCards() == [card])
}

@MainActor
@Test func deletingTagKeepsCard() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repositories = TestRepositories(container: container)
    let tag = try await repositories.tags.create(name: "Exam")
    try await repositories.cards.save(.fixture(tag: tag))

    try await repositories.tags.delete(id: tag.id)

    #expect(try await repositories.cards.fetchCards().count == 1)
    #expect(try await repositories.cards.fetchCards().first?.tags.isEmpty == true)
}

@MainActor
@Test func fetchingTagsSortsByName() async throws {
    let repository = SwiftDataTagRepository(
        container: try ModelContainerFactory.makeInMemory()
    )
    let work = try await repository.create(name: "Work")
    let exam = try await repository.create(name: "Exam")

    #expect(try await repository.fetchTags() == [exam, work])
}

@MainActor
@Test func creatingAnExistingTagNameReturnsTheExistingTag() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataTagRepository(container: container)
    let original = try await repository.create(name: "Work")

    let duplicate = try await repository.create(name: "Work")

    #expect(duplicate == original)
    #expect(try await repository.fetchTags() == [original])
}

@MainActor
@Test func creatingACaseEquivalentTagReturnsTheFirstTag() async throws {
    let repository = SwiftDataTagRepository(
        container: try ModelContainerFactory.makeInMemory()
    )
    let original = try await repository.create(name: "Work")

    let duplicate = try await repository.create(name: "work")

    #expect(duplicate == original)
    #expect(try await repository.fetchTags() == [original])
}

@MainActor
@Test func creatingAWhitespaceEquivalentTagPreservesTheFirstDisplayName() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataTagRepository(container: container)
    let original = try await repository.create(name: "Project   Notes")

    let duplicate = try await repository.create(name: "  Project\tNotes  ")

    #expect(duplicate == original)
    #expect(try await repository.fetchTags() == [original])
    let entities = try container.mainContext.fetch(FetchDescriptor<TagEntity>())
    #expect(entities.map(\.normalizedName) == ["project notes"])
}

@MainActor
@Test func renamingTagPreservesIdentityAndCardState() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repositories = TestRepositories(container: container)
    let work = try await repositories.tags.create(name: "Work")
    let card = VocabularyCard.fixture(tag: work, isLearned: true)
    try await repositories.cards.save(card)

    let renamed = try await repositories.tags.rename(id: work.id, name: "Deep Work")
    let fetchedCards = try await repositories.cards.fetchCards()
    let fetchedCard = try #require(fetchedCards.first)

    #expect(renamed == Tag(id: work.id, name: "Deep Work"))
    #expect(fetchedCard.tags == [renamed])
    #expect(fetchedCard.isLearned)
    #expect(fetchedCard.createdAt == card.createdAt)
    #expect(fetchedCard.updatedAt == card.updatedAt)
}

@MainActor
@Test func renamingToAnExistingNormalizedNameReportsConflict() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataTagRepository(container: container)
    let work = try await repository.create(name: "Work")
    let exam = try await repository.create(name: "Exam Prep")

    do {
        _ = try await repository.rename(id: work.id, name: "  exam   prep ")
        Issue.record("Expected duplicate tag name to be rejected")
    } catch let error as TagRepositoryError {
        #expect(error == .duplicateName(existingTagID: exam.id))
    }
    let tags = try await repository.fetchTags()
    #expect(tags == [exam, work])
}

@MainActor
@Test func mergingTagsMovesCardsWithoutDuplicatesOrStateLoss() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repositories = TestRepositories(container: container)
    let work = try await repositories.tags.create(name: "Work")
    let exam = try await repositories.tags.create(name: "Exam")
    let sourceOnly = VocabularyCard.fixture(tag: work, isLearned: true)
    let both = VocabularyCard.singleValueFixture(
        id: TestIDs.secondCard,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "экзамен",
        english: "exam",
        updatedAt: TestDates.updated
    ).updating(tags: [work, exam], isLearned: true)
    try await repositories.cards.save(sourceOnly)
    try await repositories.cards.save(both)

    try await repositories.tags.merge(id: work.id, into: exam.id)

    let tags = try await repositories.tags.fetchTags()
    #expect(tags == [exam])
    let cards = try await repositories.cards.fetchCards()
    let allCardsHaveDestinationTag = cards.allSatisfy { $0.tags == [exam] }
    let allCardsRemainLearned = cards.allSatisfy(\.isLearned)
    #expect(allCardsHaveDestinationTag)
    #expect(allCardsRemainLearned)
    #expect(cards.first(where: { $0.id == sourceOnly.id })?.updatedAt == sourceOnly.updatedAt)
    #expect(cards.first(where: { $0.id == both.id })?.updatedAt == both.updatedAt)
}

@MainActor
@Test func createdTagSurvivesRecreatingADiskBackedContainer() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CardFlipperTagPersistence-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let storeURL = directory.appendingPathComponent("default.store")
    let original: Core.Tag

    do {
        let configuration = ModelConfiguration(
            "TagPersistenceTest",
            schema: CardFlipperSchema.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: CardFlipperSchema.schema,
            configurations: [configuration]
        )
        let repository = SwiftDataTagRepository(container: container)
        original = try await repository.create(name: "Reusable")
    }

    do {
        let configuration = ModelConfiguration(
            "TagPersistenceTest",
            schema: CardFlipperSchema.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: CardFlipperSchema.schema,
            configurations: [configuration]
        )
        let repository = SwiftDataTagRepository(container: container)

        #expect(try await repository.fetchTags() == [original])
    }
}

@MainActor
@Test func cardRepositoryRetainsItsModelContainer() async throws {
    let repository = SwiftDataCardRepository(
        container: try ModelContainerFactory.makeInMemory()
    )
    let card = VocabularyCard.fixture()

    try await repository.save(card)

    #expect(try await repository.fetchCards() == [card])
}

@MainActor
@Test func savingAnExistingCardReplacesItsOwnedValues() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataCardRepository(container: container)
    try await repository.save(.fixture())
    let replacement = VocabularyCard(
        id: TestIDs.card,
        russianMeanings: [
            RussianMeaning(id: TestIDs.russianMeaningOne, text: "дело"),
        ],
        englishVariants: [
            EnglishVariant(
                id: TestIDs.englishVariantOne,
                text: "business",
                ipa: "ˈbɪznəs",
                partsOfSpeech: [.noun],
                usageExamples: [
                    UsageExample(
                        id: TestIDs.usageExampleOne,
                        text: "Business is growing.",
                        partOfSpeech: .noun
                    ),
                ]
            ),
        ],
        tags: [],
        createdAt: TestDates.created,
        updatedAt: Date(timeIntervalSince1970: 3_000)
    )

    try await repository.save(replacement)

    #expect(try await repository.fetchCards() == [replacement])
    #expect(try container.mainContext.fetchCount(FetchDescriptor<RussianMeaningEntity>()) == 1)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<EnglishVariantEntity>()) == 1)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<UsageExampleEntity>()) == 1)
}

@MainActor
@Test func deletingCardCascadesOwnedValuesAndKeepsTags() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repositories = TestRepositories(container: container)
    let tag = try await repositories.tags.create(name: "Work")
    try await repositories.cards.save(.fixture(tag: tag))

    try await repositories.cards.delete(id: TestIDs.card)

    #expect(try await repositories.cards.fetchCards().isEmpty)
    #expect(try await repositories.tags.fetchTags() == [tag])
    #expect(try container.mainContext.fetchCount(FetchDescriptor<RussianMeaningEntity>()) == 0)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<EnglishVariantEntity>()) == 0)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<UsageExampleEntity>()) == 0)
}

@MainActor
@Test func cardWithoutUsageExamplesRoundTripsWithEmptyExamples() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataCardRepository(container: container)
    let card = VocabularyCard.singleValueFixture(
        id: TestIDs.secondCard,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "дом",
        english: "home",
        updatedAt: TestDates.updated
    )

    try await repository.save(card)

    #expect(try await repository.fetchCards() == [card])
    #expect(try container.mainContext.fetchCount(FetchDescriptor<UsageExampleEntity>()) == 0)
}

@MainActor
@Test func duplicateCandidatesMatchNormalizedValuesOnEitherLanguageSide() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataCardRepository(container: container)
    let russianMatch = VocabularyCard.singleValueFixture(
        id: TestIDs.card,
        russianMeaningID: TestIDs.russianMeaningOne,
        englishVariantID: TestIDs.englishVariantOne,
        russian: "работа",
        english: "work",
        updatedAt: Date(timeIntervalSince1970: 2_000)
    )
    let englishMatch = VocabularyCard.singleValueFixture(
        id: TestIDs.secondCard,
        russianMeaningID: TestIDs.secondRussianMeaning,
        englishVariantID: TestIDs.secondEnglishVariant,
        russian: "экзамен",
        english: "test",
        updatedAt: Date(timeIntervalSince1970: 3_000)
    )
    try await repository.save(russianMatch)
    try await repository.save(englishMatch)
    let draft = CardDraft(
        russianMeanings: ["  РАБОТА  "],
        englishVariants: [EnglishVariantDraft(text: "  TEST  ")],
        tagIDs: []
    )

    let candidates = try await repository.duplicateCandidates(
        for: draft,
        excluding: nil
    )

    #expect(candidates == [englishMatch, russianMatch])
}

@MainActor
@Test func duplicateCandidatesExcludeTheEditedCard() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataCardRepository(container: container)
    let card = VocabularyCard.fixture()
    try await repository.save(card)
    let draft = CardDraft(
        russianMeanings: ["работа"],
        englishVariants: [EnglishVariantDraft(text: "work")],
        tagIDs: []
    )

    let candidates = try await repository.duplicateCandidates(
        for: draft,
        excluding: card.id
    )

    #expect(candidates.isEmpty)
}
