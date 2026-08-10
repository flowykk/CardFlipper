import Foundation
import Testing
@testable import Core
@testable import LibraryFeature

@MainActor
@Test func loadPublishesCardsAndTags() async {
    let card = VocabularyCard.workCard
    let tag = Tag.work
    let model = LibraryViewModel(
        cards: CardRepositoryFake([card]),
        tags: TagRepositoryFake([tag])
    )

    await model.load()

    #expect(model.cards == [card])
    #expect(model.tags == [tag])
    #expect(model.state == .loaded)
}

@MainActor
@Test func loadFailureKeepsPreviouslyLoadedValues() async {
    let cardRepository = CardRepositoryFake([.workCard])
    let tagRepository = TagRepositoryFake([.work])
    let model = LibraryViewModel(cards: cardRepository, tags: tagRepository)
    await model.load()
    cardRepository.fetchedCards = [.examCard]
    tagRepository.fetchedTags = [.exam]
    tagRepository.fetchError = LibraryTestError.fetch

    await model.load()

    #expect(model.cards == [.workCard])
    #expect(model.tags == [.work])
    #expect(model.state == .failed)
}

@MainActor
@Test func retryCanRecoverFromLoadFailure() async {
    let cardRepository = CardRepositoryFake(fetchError: LibraryTestError.fetch)
    let tagRepository = TagRepositoryFake([.work])
    let model = LibraryViewModel(cards: cardRepository, tags: tagRepository)
    await model.load()
    cardRepository.fetchError = nil
    cardRepository.fetchedCards = [.workCard]

    await model.load()

    #expect(model.cards == [.workCard])
    #expect(model.tags == [.work])
    #expect(model.state == .loaded)
}

@MainActor
@Test(arguments: [
    (query: "  WORK  ", expectedID: UUID.fixture(101)),
    (query: "  РАБОТА  ", expectedID: UUID.fixture(101)),
])
func searchMatchesEitherLanguage(query: String, expectedID: UUID) async {
    let model = LibraryViewModel(
        cards: CardRepositoryFake([.workCard, .examCard]),
        tags: TagRepositoryFake()
    )
    await model.load()

    model.searchText = query

    #expect(model.visibleCards.map(\.id) == [expectedID])
}

@MainActor
@Test func noSelectedTagsShowsAllCards() async {
    let model = LibraryViewModel(
        cards: CardRepositoryFake(VocabularyCard.taggedFixtures),
        tags: TagRepositoryFake(Tag.fixtures)
    )
    await model.load()

    model.selectedTagIDs = []

    #expect(model.visibleCards.map(\.id) == VocabularyCard.taggedFixtures.map(\.id))
}

@MainActor
@Test func selectedTagsUseORSemantics() async {
    let model = LibraryViewModel(
        cards: CardRepositoryFake(VocabularyCard.taggedFixtures),
        tags: TagRepositoryFake(Tag.fixtures)
    )
    await model.load()

    model.selectedTagIDs = [UUID.fixture(1), UUID.fixture(2)]

    #expect(Set(model.visibleCards.map(\.id)) == Set<UUID>([
        .fixture(101), .fixture(102), .fixture(103),
    ]))
}

@MainActor
@Test func searchAndTagSelectionBothConstrainResults() async {
    let model = LibraryViewModel(
        cards: CardRepositoryFake(VocabularyCard.taggedFixtures),
        tags: TagRepositoryFake(Tag.fixtures)
    )
    await model.load()

    model.selectedTagIDs = [UUID.fixture(1), UUID.fixture(2)]
    model.searchText = "exam"

    #expect(model.visibleCards.map(\.id) == [.fixture(102)])
}

@MainActor
@Test func deletingCardRemovesOnlyTheConfirmedCard() async {
    let repository = CardRepositoryFake([.workCard, .examCard])
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake())
    await model.load()
    model.pendingDeletion = .workCard

    await model.deletePendingCard()

    #expect(model.cards == [.examCard])
    #expect(model.pendingDeletion == nil)
    #expect(model.deletionFailure == nil)
    #expect(repository.deletedIDs == [.fixture(101)])
}

@MainActor
@Test func failedCardDeletionPreservesLoadedStateAndPendingCard() async {
    let repository = CardRepositoryFake(
        [.workCard, .examCard],
        deletionError: LibraryTestError.delete
    )
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake())
    await model.load()
    model.pendingDeletion = .workCard

    await model.deletePendingCard()

    #expect(model.cards == [.workCard, .examCard])
    #expect(model.pendingDeletion == .workCard)
    #expect(model.deletionFailure == .card)
    #expect(model.state == .loaded)
}

@MainActor
@Test func cardDeletionReportsWhetherCompositionShouldRefresh() async {
    let successfulRepository = CardRepositoryFake([.workCard])
    let successfulModel = LibraryViewModel(
        cards: successfulRepository,
        tags: TagRepositoryFake()
    )
    await successfulModel.load()
    successfulModel.pendingDeletion = .workCard
    let successfulDeletion = await successfulModel.deletePendingCard()

    let failingRepository = CardRepositoryFake(
        [.workCard],
        deletionError: LibraryTestError.delete
    )
    let failingModel = LibraryViewModel(
        cards: failingRepository,
        tags: TagRepositoryFake()
    )
    await failingModel.load()
    failingModel.pendingDeletion = .workCard
    let failedDeletion = await failingModel.deletePendingCard()

    #expect(successfulDeletion)
    #expect(!failedDeletion)
}

@MainActor
@Test func deletingTagPreservesCardsAndRemovesTheirAssociations() async {
    let repository = TagRepositoryFake(Tag.fixtures)
    let model = LibraryViewModel(
        cards: CardRepositoryFake(VocabularyCard.taggedFixtures),
        tags: repository
    )
    await model.load()
    model.selectedTagIDs = [Tag.work.id]
    model.pendingTagDeletion = Tag.work

    await model.deletePendingTag()

    #expect(model.cards.map(\.id) == VocabularyCard.taggedFixtures.map(\.id))
    #expect(model.cards.allSatisfy { !$0.tags.contains(Tag.work) })
    #expect(model.tags == [Tag.exam, Tag.travel])
    #expect(model.selectedTagIDs.isEmpty)
    #expect(model.pendingTagDeletion == nil)
    #expect(model.deletionFailure == nil)
    #expect(repository.deletedIDs == [Tag.work.id])
}

@MainActor
@Test func failedTagDeletionPreservesCardsTagsAndSelection() async {
    let repository = TagRepositoryFake(
        Tag.fixtures,
        deletionError: LibraryTestError.delete
    )
    let model = LibraryViewModel(
        cards: CardRepositoryFake(VocabularyCard.taggedFixtures),
        tags: repository
    )
    await model.load()
    model.selectedTagIDs = [Tag.work.id]
    model.pendingTagDeletion = Tag.work

    await model.deletePendingTag()

    #expect(model.cards == VocabularyCard.taggedFixtures)
    #expect(model.tags == Tag.fixtures)
    #expect(model.selectedTagIDs == [Tag.work.id])
    #expect(model.pendingTagDeletion == Tag.work)
    #expect(model.deletionFailure == .tag)
    #expect(model.state == .loaded)
}

@MainActor
@Test func tagDeletionReportsWhetherCompositionShouldRefresh() async {
    let successfulRepository = TagRepositoryFake([.work])
    let successfulModel = LibraryViewModel(
        cards: CardRepositoryFake([.workCard]),
        tags: successfulRepository
    )
    await successfulModel.load()
    successfulModel.pendingTagDeletion = .work
    let successfulDeletion = await successfulModel.deletePendingTag()

    let failingRepository = TagRepositoryFake(
        [.work],
        deletionError: LibraryTestError.delete
    )
    let failingModel = LibraryViewModel(
        cards: CardRepositoryFake([.workCard]),
        tags: failingRepository
    )
    await failingModel.load()
    failingModel.pendingTagDeletion = .work
    let failedDeletion = await failingModel.deletePendingTag()

    #expect(successfulDeletion)
    #expect(!failedDeletion)
}
