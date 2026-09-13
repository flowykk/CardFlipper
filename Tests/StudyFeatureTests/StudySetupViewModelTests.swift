import Core
import Testing
@testable import StudyFeature

@MainActor
@Test func setupDefaultsToEnglishToRussianAndCanStart() {
    let model = StudySetupViewModel(cards: [.fixture(id: 1)], tags: [])

    #expect(model.direction == .englishToRussian)
    #expect(model.canStart)
    #expect(model.configuration?.direction == .englishToRussian)
    #expect(model.mode == .flashcards)
    #expect(model.configuration?.mode == .flashcards)
}

@MainActor
@Test func writingModeForcesRussianToEnglishAndPreservesFilters() {
    let learnedWork = VocabularyCard.fixture(id: 1, tags: [.work], isLearned: true)
    let other = VocabularyCard.fixture(id: 2, tags: [.exam])
    let model = StudySetupViewModel(
        cards: [learnedWork, other],
        tags: [.work, .exam]
    )
    model.learningFilter = .learned
    model.toggleTag(Tag.work.id)

    model.chooseMode(.writing)

    #expect(model.mode == .writing)
    #expect(model.direction == .russianToEnglish)
    #expect(model.configuration == StudyConfiguration(
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagIDs: [Tag.work.id],
        cards: [learnedWork]
    ))
}

@MainActor
@Test func returningToFlashcardsRestoresLastFlashcardDirection() {
    let model = StudySetupViewModel(cards: [.fixture(id: 1)], tags: [])
    model.chooseDirection(.englishToRussian)
    model.chooseMode(.writing)

    model.chooseMode(.flashcards)

    #expect(model.direction == .englishToRussian)
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
@Test func learnedFilterCombinesWithTagSelection() {
    let learnedWork = VocabularyCard.fixture(id: 1, tags: [.work], isLearned: true)
    let unlearnedWork = VocabularyCard.fixture(id: 2, tags: [.work])
    let learnedExam = VocabularyCard.fixture(id: 3, tags: [.exam], isLearned: true)
    let model = StudySetupViewModel(
        cards: [learnedWork, unlearnedWork, learnedExam], tags: [.work, .exam]
    )
    model.learningFilter = .learned
    model.toggleTag(Tag.work.id)

    #expect(model.matchingCards == [learnedWork])
    #expect(model.configuration?.cards == [learnedWork])
}

@MainActor
@Test func unlearnedFilterDisablesStudyWhenNoCardsMatch() {
    let model = StudySetupViewModel(
        cards: [.fixture(id: 1, isLearned: true)], tags: []
    )
    model.learningFilter = .unlearned

    #expect(model.matchingCards.isEmpty)
    #expect(model.canStart == false)
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
