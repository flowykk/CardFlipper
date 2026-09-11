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
@Test func learnedFilterCombinesWithTagSelection() async {
    let learnedWork = VocabularyCard.fixture(
        id: .fixture(201), russian: "работа", english: "work", tags: [.work], isLearned: true
    )
    let unlearnedWork = VocabularyCard.fixture(
        id: .fixture(202), russian: "дело", english: "business", tags: [.work]
    )
    let model = LibraryViewModel(
        cards: CardRepositoryFake([learnedWork, unlearnedWork]), tags: TagRepositoryFake([.work])
    )
    await model.load()
    model.selectedTagIDs = [Tag.work.id]
    model.learningFilter = .learned

    #expect(model.visibleCards == [learnedWork])
}

@MainActor
@Test func markingCardLearnedPersistsAndUpdatesTheVisibleCards() async {
    let card = VocabularyCard.workCard
    let repository = CardRepositoryFake([card])
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake())
    await model.load()
    model.learningFilter = .unlearned

    let changed = await model.toggleLearningStatus(for: card)

    #expect(changed)
    #expect(model.cards.first?.isLearned == true)
    #expect(model.visibleCards.isEmpty)
    #expect(repository.savedCards.first?.isLearned == true)
}

@MainActor
@Test func failedLearningStatusChangeKeepsTheCardUnchanged() async {
    let card = VocabularyCard.workCard
    let model = LibraryViewModel(
        cards: CardRepositoryFake([card], saveError: LibraryTestError.delete), tags: TagRepositoryFake()
    )
    await model.load()

    let changed = await model.toggleLearningStatus(for: card)

    #expect(!changed)
    #expect(model.cards == [card])
    #expect(model.learningStatusFailure == card)
}

@MainActor
@Test func successfulLearningStatusChangeOffersUndo() async {
    let card = VocabularyCard.workCard
    let model = LibraryViewModel(
        cards: CardRepositoryFake([card]),
        tags: TagRepositoryFake()
    )
    await model.load()

    await model.toggleLearningStatus(for: card)

    #expect(model.undoAction == .learningStatus(cardID: card.id, previousValue: false))
}

@MainActor
@Test func undoLearningStatusPersistsThePreviousValue() async {
    let card = VocabularyCard.workCard
    let repository = CardRepositoryFake([card])
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake())
    await model.load()
    await model.toggleLearningStatus(for: card)

    let undone = await model.performUndo()

    #expect(undone)
    #expect(model.cards.first?.isLearned == false)
    #expect(repository.savedCards.map(\.isLearned) == [true, false])
    #expect(model.undoAction == nil)
    #expect(!model.undoFailed)
}

@MainActor
@Test func failedUndoKeepsCurrentStateAndOffersRetry() async {
    let card = VocabularyCard.workCard
    let repository = CardRepositoryFake([card])
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake())
    await model.load()
    await model.toggleLearningStatus(for: card)
    repository.saveError = LibraryTestError.delete

    let undone = await model.performUndo()

    #expect(!undone)
    #expect(model.cards.first?.isLearned == true)
    #expect(model.undoAction == .learningStatus(cardID: card.id, previousValue: false))
    #expect(model.undoFailed)
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
    #expect(model.undoAction == .deletedCard(.workCard))
}

@MainActor
@Test func undoCardDeletionRestoresAndPersistsTheCard() async {
    let repository = CardRepositoryFake([.workCard, .examCard])
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake())
    await model.load()
    model.pendingDeletion = .workCard
    await model.deletePendingCard()

    let undone = await model.performUndo()

    #expect(undone)
    #expect(model.cards.contains(.workCard))
    #expect(repository.savedCards == [.workCard])
    #expect(model.undoAction == nil)
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

@MainActor
@Test func bulkTagAssignmentAddsTagsWithoutRemovingExistingTagsOrCreatingDuplicates() async {
    let repository = CardRepositoryFake(VocabularyCard.taggedFixtures)
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake(Tag.fixtures))
    await model.load()

    model.beginBulkTagSelection()
    model.toggleBulkCardSelection(id: VocabularyCard.workCard.id)
    model.toggleBulkCardSelection(id: VocabularyCard.sharedCard.id)
    let changed = await model.addTagsToSelectedCards(ids: [Tag.exam.id])

    #expect(changed)
    #expect(model.cards.first(where: { $0.id == VocabularyCard.workCard.id })?.tags == [.work, .exam])
    #expect(model.cards.first(where: { $0.id == VocabularyCard.sharedCard.id })?.tags == [.work, .exam])
    #expect(repository.addedTagIDs == [Tag.exam.id])
    #expect(repository.addedTagCardIDs == [VocabularyCard.workCard.id, VocabularyCard.sharedCard.id])
    #expect(!model.isBulkTagSelectionActive)
    #expect(model.selectedBulkCardIDs.isEmpty)
}

@MainActor
@Test func bulkTagAssignmentPreservesLearnedStateAndDates() async {
    let learnedCard = VocabularyCard.fixture(
        id: .fixture(104),
        russian: "изучено",
        english: "learned",
        tags: [.work],
        isLearned: true
    )
    let repository = CardRepositoryFake([learnedCard])
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake(Tag.fixtures))
    await model.load()

    model.beginBulkTagSelection()
    model.toggleBulkCardSelection(id: learnedCard.id)
    let changed = await model.addTagsToSelectedCards(ids: [Tag.exam.id])

    let updatedCard = model.cards.first
    #expect(changed)
    #expect(updatedCard?.isLearned == true)
    #expect(updatedCard?.createdAt == learnedCard.createdAt)
    #expect(updatedCard?.updatedAt == learnedCard.updatedAt)
    #expect(updatedCard?.tags == [.work, .exam])
}

@MainActor
@Test func failedBulkTagAssignmentKeepsCardsAndSelectedIDsUnchanged() async {
    let repository = CardRepositoryFake(
        VocabularyCard.taggedFixtures,
        addTagsError: LibraryTestError.delete
    )
    let model = LibraryViewModel(cards: repository, tags: TagRepositoryFake(Tag.fixtures))
    await model.load()
    model.beginBulkTagSelection()
    model.toggleBulkCardSelection(id: VocabularyCard.workCard.id)

    let changed = await model.addTagsToSelectedCards(ids: [Tag.exam.id])

    #expect(!changed)
    #expect(model.cards == VocabularyCard.taggedFixtures)
    #expect(model.selectedBulkCardIDs == [VocabularyCard.workCard.id])
    #expect(model.isBulkTagSelectionActive)
}

@MainActor
@Test func bulkCardSelectionPersistsWhenSearchAndTagFiltersChange() async {
    let model = LibraryViewModel(
        cards: CardRepositoryFake(VocabularyCard.taggedFixtures),
        tags: TagRepositoryFake(Tag.fixtures)
    )
    await model.load()
    model.beginBulkTagSelection()
    model.toggleBulkCardSelection(id: VocabularyCard.workCard.id)

    model.searchText = "exam"
    model.selectedTagIDs = [Tag.exam.id]

    #expect(model.visibleCards == [VocabularyCard.examCard])
    #expect(model.selectedBulkCardIDs == [VocabularyCard.workCard.id])
}
