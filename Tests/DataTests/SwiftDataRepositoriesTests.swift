import Foundation
import SwiftData
import Testing
@testable import Core
@testable import Data

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
