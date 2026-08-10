import Core
import Testing
@testable import StudyFeature

@MainActor
@Test func setupDefaultsToEnglishToRussianAndCanStart() {
    let model = StudySetupViewModel(cards: [.fixture(id: 1)], tags: [])

    #expect(model.direction == .englishToRussian)
    #expect(model.canStart)
    #expect(model.configuration?.direction == .englishToRussian)
}

@MainActor
@Test func noSelectedTagsIncludesEveryCard() {
    let cards = [VocabularyCard.fixture(id: 1), .fixture(id: 2)]
    let model = StudySetupViewModel(cards: cards, tags: [])

    #expect(model.matchingCards == cards)
}

@MainActor
@Test func multipleSelectedTagsUseORSemantics() {
    let workCard = VocabularyCard.fixture(id: 1, tags: [.work])
    let examCard = VocabularyCard.fixture(id: 2, tags: [.exam])
    let untaggedCard = VocabularyCard.fixture(id: 3)
    let model = StudySetupViewModel(
        cards: [workCard, examCard, untaggedCard],
        tags: [.work, .exam]
    )

    model.toggleTag(Tag.work.id)
    model.toggleTag(Tag.exam.id)

    #expect(model.matchingCards.map(\.id) == [workCard.id, examCard.id])
}

@MainActor
@Test func noTagMatchesDisablesStartAndProducesNoConfiguration() {
    let model = StudySetupViewModel(
        cards: [.fixture(id: 1, tags: [.work])],
        tags: [.work, .exam]
    )
    model.chooseDirection(.russianToEnglish)
    model.toggleTag(Tag.exam.id)

    #expect(model.matchingCards.isEmpty)
    #expect(model.canStart == false)
    #expect(model.configuration == nil)
}

@MainActor
@Test func configurationPreservesDirectionFiltersAndOriginalMatchingOrder() {
    let first = VocabularyCard.fixture(id: 1, tags: [.work, .exam])
    let second = VocabularyCard.fixture(id: 2, tags: [.exam])
    let excluded = VocabularyCard.fixture(id: 3, tags: [.work])
    let model = StudySetupViewModel(
        cards: [first, second, excluded],
        tags: [.work, .exam]
    )
    model.chooseDirection(.englishToRussian)
    model.toggleTag(Tag.exam.id)

    #expect(
        model.configuration == StudyConfiguration(
            direction: .englishToRussian,
            selectedTagIDs: [Tag.exam.id],
            cards: [first, second]
        )
    )
}
