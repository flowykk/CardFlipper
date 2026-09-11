import Core
import Foundation
import Testing
@testable import StudyFeature

@MainActor
@Test func sessionShufflesAllMatchingCardsExactlyOnce() {
    let shuffler = CountingShuffler()
    let model = StudySessionViewModel(
        configuration: .fixture,
        shuffler: shuffler,
        speech: SpeechServiceSpy(),
        feedback: StudyFeedbackSpy()
    )

    #expect(shuffler.invocationCount == 1)
    #expect(model.session.queue.map(\.id) == StudyConfiguration.fixture.cards.reversed().map(\.id))
    #expect(model.repeatConfiguration == .fixture)
}

@MainActor
@Test func sessionPersistsAfterRevealAssessmentAndExplicitBackgroundSave() throws {
    let store = StudySessionStoreSpy()
    let model = makeSession(store: store)
    let initialSaves = store.saveCount

    model.toggleCardSide()
    #expect(store.saveCount == initialSaves + 1)
    #expect(store.storedSnapshot?.isShowingAnswer == true)
    #expect(store.storedSnapshot?.isRevealed == true)

    try model.forget()
    #expect(store.saveCount == initialSaves + 2)
    #expect(store.storedSnapshot?.queueCardIDs == [
        StudyConfiguration.fixture.cards[1].id,
        StudyConfiguration.fixture.cards[0].id,
    ])

    model.persistSnapshot()
    #expect(store.saveCount == initialSaves + 3)
}

@MainActor
@Test func snapshotRestoresExactQueueFaceCountersAndElapsedTimeWithoutShuffling() throws {
    let configuration = StudyConfiguration.fixture
    let snapshot = StudySessionSnapshot(
        direction: configuration.direction,
        selectedTagIDs: configuration.selectedTagIDs,
        originalCardIDs: configuration.cards.map(\.id),
        queueCardIDs: [configuration.cards[1].id, configuration.cards[0].id],
        isShowingAnswer: true,
        isRevealed: true,
        forgottenCount: 1,
        repeatedCardIDs: [configuration.cards[0].id],
        totalAssessmentCount: 2,
        accumulatedDurationSeconds: 30
    )
    let shuffler = CountingShuffler()
    var currentTime = Date(timeIntervalSince1970: 1_000)
    let model = StudySessionViewModel(
        configuration: configuration,
        snapshot: snapshot,
        shuffler: shuffler,
        speech: SpeechServiceSpy(),
        feedback: StudyFeedbackSpy(),
        now: { currentTime }
    )

    #expect(shuffler.invocationCount == 0)
    #expect(model.session.queue.map(\.id) == snapshot.queueCardIDs)
    #expect(model.isShowingAnswer)
    #expect(model.canAssess)
    #expect(model.session.forgottenCount == 1)
    currentTime = Date(timeIntervalSince1970: 1_012)
    model.toggleCardSide()
    try model.remember()
    model.toggleCardSide()
    try model.remember()
    #expect(model.result?.elapsedSeconds == 42)
}

@MainActor
@Test func snapshotExcludesMissingCardsAndCompletedResultDoesNotRestartQueue() {
    let available = StudyConfiguration.fixture.cards[1]
    let result = StudyResult(
        reviewedCardCount: 2,
        repeatedCardIDs: [StudyConfiguration.fixture.cards[0].id],
        totalAssessmentCount: 3,
        elapsedSeconds: 20
    )
    let snapshot = StudySessionSnapshot(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        queueCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 1,
        repeatedCardIDs: result.repeatedCardIDs,
        totalAssessmentCount: 3,
        accumulatedDurationSeconds: 20,
        completedResult: result
    )
    let model = StudySessionViewModel(
        configuration: StudyConfiguration(
            direction: .russianToEnglish,
            selectedTagIDs: [],
            cards: [available]
        ),
        snapshot: snapshot,
        shuffler: CountingShuffler(),
        speech: SpeechServiceSpy(),
        feedback: StudyFeedbackSpy()
    )

    #expect(model.session.queue.map(\.id) == [available.id])
    #expect(model.session.initialCardCount == 1)
    #expect(model.result == result)
}

@MainActor
@Test func assessmentIsGuardedUntilReveal() {
    let feedback = StudyFeedbackSpy()
    let model = makeSession(feedback: feedback)

    #expect(model.canAssess == false)
    #expect(throws: StudySessionError.answerNotRevealed) { try model.remember() }
    #expect(feedback.events.isEmpty)

    model.toggleCardSide()

    #expect(model.canAssess)
    #expect(model.isShowingAnswer)
    #expect(feedback.events == [.reveal])
}

@MainActor
@Test func cardCanReturnToPromptWithoutLockingAssessment() {
    let feedback = StudyFeedbackSpy()
    let model = makeSession(feedback: feedback)

    model.toggleCardSide()
    #expect(model.isShowingAnswer)
    #expect(model.canAssess)

    model.toggleCardSide()
    #expect(model.isShowingAnswer == false)
    #expect(model.canAssess)
    #expect(feedback.events == [.reveal, .reveal])
}

@MainActor
@Test func usageExamplesCanBeExpandedOnlyAfterAssessmentUnlocks() {
    let model = makeSession(configuration: configurationWithUsageExamples)

    #expect(model.hasUsageExamples)
    #expect(model.isShowingUsageExamples == false)
    model.toggleUsageExamples()
    #expect(model.isShowingUsageExamples == false)
    model.toggleCardSide()
    model.toggleUsageExamples()
    #expect(model.isShowingUsageExamples)
    model.toggleCardSide()
    #expect(model.isShowingUsageExamples)
}

@MainActor
@Test func rememberRemovesCurrentCardAndResetsReveal() throws {
    let feedback = StudyFeedbackSpy()
    let model = makeSession(feedback: feedback)
    let secondCardID = StudyConfiguration.fixture.cards[1].id

    model.toggleCardSide()
    try model.remember()

    #expect(model.session.currentCard?.id == secondCardID)
    #expect(model.session.remainingCount == 1)
    #expect(model.isShowingAnswer == false)
    #expect(model.canAssess == false)
    #expect(model.result == nil)
    #expect(feedback.events == [.reveal, .remember])
}

@MainActor
@Test func rememberResetsUsageExampleDisclosureAfterTheQueueAdvances() throws {
    let model = makeSession(configuration: configurationWithUsageExamples)

    model.toggleCardSide()
    model.toggleUsageExamples()
    try model.remember()

    #expect(model.isShowingUsageExamples == false)
}

@MainActor
@Test func forgetAppendsCurrentCardAndCountsEveryForget() throws {
    let feedback = StudyFeedbackSpy()
    let model = makeSession(feedback: feedback)
    let firstCardID = StudyConfiguration.fixture.cards[0].id
    let secondCardID = StudyConfiguration.fixture.cards[1].id

    model.toggleCardSide()
    try model.forget()

    #expect(model.session.queue.map(\.id) == [secondCardID, firstCardID])
    #expect(model.session.forgottenCount == 1)
    #expect(model.isShowingAnswer == false)
    #expect(model.result == nil)
    #expect(feedback.events == [.reveal, .forget])
}

@MainActor
@Test func forgetResetsUsageExampleDisclosureAfterTheQueueAdvances() throws {
    let model = makeSession(configuration: configurationWithUsageExamples)

    model.toggleCardSide()
    model.toggleUsageExamples()
    try model.forget()

    #expect(model.isShowingUsageExamples == false)
}

@MainActor
@Test func resultAppearsOnlyAfterEveryCardIsRemembered() throws {
    let feedback = StudyFeedbackSpy()
    let model = makeSession(feedback: feedback)

    model.toggleCardSide()
    try model.forget()
    model.toggleCardSide()
    try model.remember()
    #expect(model.result == nil)
    model.toggleCardSide()
    try model.remember()

    #expect(model.result == StudyResult(
        reviewedCardCount: 2,
        repeatedCardIDs: [StudyConfiguration.fixture.cards[0].id],
        totalAssessmentCount: 3,
        elapsedSeconds: 0
    ))
    #expect(model.repeatConfiguration == .fixture)
    #expect(model.difficultRepeatConfiguration?.cards == [StudyConfiguration.fixture.cards[0]])
    #expect(feedback.events == [
        .reveal,
        .forget,
        .reveal,
        .remember,
        .reveal,
        .completion,
    ])
}

@Test func resultPresentationMapsRepeatedCardsAndProgress() {
    let difficultCards = Array(StudyConfiguration.fixture.cards.prefix(2))
    let presentation = StudyResultPresentation(
        result: StudyResult(
            reviewedCardCount: 3,
            repeatedCardIDs: difficultCards.map(\.id),
            totalAssessmentCount: 5,
            elapsedSeconds: 125
        ),
        difficultCards: difficultCards,
        dailyGoalProgress: StudyDailyGoalProgress(elapsedSeconds: 450, goalSeconds: 900)
    )

    #expect(presentation.reviewedCards == StudyResultMetric(
        localizationKey: "study.result.cards",
        count: 3
    ))
    #expect(presentation.repeatedCards == StudyResultMetric(
        localizationKey: "study.result.cardsRepeated",
        count: 2
    ))
    #expect(presentation.recallRatePercentage == 33)
    #expect(presentation.durationText == "2:05")
    #expect(presentation.difficultCardTitles.count == 2)
    #expect(presentation.dailyGoalPercentage == 50)
}

@Test func resultPresentationHandlesNoDifficultCards() {
    let presentation = StudyResultPresentation(
        result: StudyResult(
            reviewedCardCount: 2,
            repeatedCardIDs: [],
            totalAssessmentCount: 2,
            elapsedSeconds: 9
        )
    )

    #expect(presentation.repeatedCards.count == 0)
    #expect(presentation.recallRatePercentage == 100)
    #expect(presentation.difficultCardTitles.isEmpty)
    #expect(presentation.dailyGoalPercentage == nil)
}

@Test func resultPresentationPreservesVeryLongDifficultCardText() {
    let longWord = "pneumonoultramicroscopicsilicovolcanoconiosis"
    let card = VocabularyCard.fixture(id: 99, english: longWord)
    let presentation = StudyResultPresentation(
        result: StudyResult(
            reviewedCardCount: 1,
            repeatedCardIDs: [card.id],
            totalAssessmentCount: 2,
            elapsedSeconds: 1
        ),
        difficultCards: [card]
    )

    #expect(presentation.difficultCardTitles == [longWord])
}

@MainActor
@Test func speechIsLimitedToTheCurrentlyVisibleEnglishSideAndVariant() {
    let speech = SpeechServiceSpy()
    let russianToEnglish = makeSession(
        configuration: .singleCard,
        speech: speech
    )
    let englishVariantID = StudyConfiguration.singleCard.cards[0].englishVariants[0].id

    russianToEnglish.speakEnglish(variantID: englishVariantID)
    #expect(speech.spokenTexts.isEmpty)
    russianToEnglish.toggleCardSide()
    russianToEnglish.speakEnglish(variantID: englishVariantID)
    russianToEnglish.toggleCardSide()
    russianToEnglish.speakEnglish(variantID: englishVariantID)
    russianToEnglish.speakEnglish(variantID: .fixture(999))
    #expect(speech.spokenTexts == ["word"])

    let englishToRussianConfiguration = StudyConfiguration(
        direction: .englishToRussian,
        selectedTagIDs: [],
        cards: [.fixture(id: 10, english: "speak")]
    )
    let englishToRussian = makeSession(
        configuration: englishToRussianConfiguration,
        speech: speech
    )
    let frontVariantID = englishToRussianConfiguration.cards[0].englishVariants[0].id
    englishToRussian.speakEnglish(variantID: frontVariantID)
    englishToRussian.toggleCardSide()
    englishToRussian.speakEnglish(variantID: frontVariantID)
    englishToRussian.toggleCardSide()
    englishToRussian.speakEnglish(variantID: frontVariantID)

    #expect(speech.spokenTexts == ["word", "speak", "speak"])
}

@MainActor
@Test func usageExampleSpeechRejectsAnExampleOwnedByAnotherCurrentVariant() {
    let speech = SpeechServiceSpy()
    let currentVariant = EnglishVariant(
        id: .fixture(3_100),
        text: "current",
        ipa: nil,
        partsOfSpeech: [.noun]
    )
    let foreignExample = UsageExample(
        id: .fixture(3_102),
        text: "The foreign variant owns this sentence.",
        partOfSpeech: .noun
    )
    let foreignVariant = EnglishVariant(
        id: .fixture(3_101),
        text: "foreign",
        ipa: nil,
        partsOfSpeech: [.noun],
        usageExamples: [foreignExample]
    )
    let card = VocabularyCard(
        id: .fixture(3_103),
        russianMeanings: [RussianMeaning(id: .fixture(3_104), text: "текущий")],
        englishVariants: [currentVariant, foreignVariant],
        tags: [],
        createdAt: .distantPast,
        updatedAt: .distantPast
    )
    let model = makeSession(
        configuration: StudyConfiguration(
            direction: .russianToEnglish,
            selectedTagIDs: [],
            cards: [card]
        ),
        speech: speech
    )

    model.toggleCardSide()
    model.toggleUsageExamples()
    model.speakUsageExample(variantID: currentVariant.id, exampleID: foreignExample.id)

    #expect(speech.spokenTexts.isEmpty)
}

@MainActor
@Test func usageExampleSpeechRequiresAssessmentDisclosureAndOwningVariant() {
    let speech = SpeechServiceSpy()
    let example = UsageExample(
        id: .fixture(3_001),
        text: "This word is useful.",
        partOfSpeech: .noun
    )
    let russianToEnglishConfiguration = StudyConfiguration(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        cards: [.fixture(id: 1, usageExamples: [example])]
    )
    let russianToEnglish = makeSession(
        configuration: russianToEnglishConfiguration,
        speech: speech
    )
    let variantID = russianToEnglishConfiguration.cards[0].englishVariants[0].id

    russianToEnglish.speakUsageExample(variantID: variantID, exampleID: example.id)
    russianToEnglish.toggleCardSide()
    russianToEnglish.speakUsageExample(variantID: variantID, exampleID: example.id)
    russianToEnglish.toggleUsageExamples()
    russianToEnglish.speakUsageExample(variantID: variantID, exampleID: example.id)
    russianToEnglish.speakUsageExample(variantID: .fixture(999), exampleID: example.id)
    russianToEnglish.toggleCardSide()
    russianToEnglish.speakUsageExample(variantID: variantID, exampleID: example.id)

    let englishToRussianConfiguration = StudyConfiguration(
        direction: .englishToRussian,
        selectedTagIDs: [],
        cards: [.fixture(id: 2, usageExamples: [example])]
    )
    let englishToRussian = makeSession(
        configuration: englishToRussianConfiguration,
        speech: speech
    )
    let frontVariantID = englishToRussianConfiguration.cards[0].englishVariants[0].id
    englishToRussian.speakUsageExample(variantID: frontVariantID, exampleID: example.id)
    englishToRussian.toggleCardSide()
    englishToRussian.toggleUsageExamples()
    englishToRussian.speakUsageExample(variantID: frontVariantID, exampleID: example.id)

    #expect(speech.spokenTexts == ["This word is useful.", "This word is useful.", "This word is useful."])
}

@MainActor
@Test func exitRequiresAnExplicitConfirmationState() {
    let model = makeSession()

    model.requestExit()
    #expect(model.isExitConfirmationPresented)
    model.cancelExit()
    #expect(model.isExitConfirmationPresented == false)
}

@Test func cardPresentationUsesRotationOrReduceMotionReplacement() {
    let prompt = StudyCardPresentation(
        cardID: .fixture(1),
        isShowingAnswer: false,
        reduceMotion: false
    )
    let answer = StudyCardPresentation(
        cardID: .fixture(1),
        isShowingAnswer: true,
        reduceMotion: false
    )
    let reducedAnswer = StudyCardPresentation(
        cardID: .fixture(1),
        isShowingAnswer: true,
        reduceMotion: true
    )

    #expect(prompt.frontRotationDegrees == 0)
    #expect(prompt.backRotationDegrees == -180)
    #expect(prompt.isFrontAccessibilityHidden == false)
    #expect(prompt.isBackAccessibilityHidden)
    #expect(answer.frontRotationDegrees == 180)
    #expect(answer.backRotationDegrees == 0)
    #expect(answer.isFrontAccessibilityHidden)
    #expect(answer.isBackAccessibilityHidden == false)
    #expect(reducedAnswer.frontRotationDegrees == 0)
    #expect(reducedAnswer.backRotationDegrees == 0)
    #expect(reducedAnswer.frontOpacity == 0)
    #expect(reducedAnswer.backOpacity == 1)
}

@Test func cardPresentationShowsExactlyOneFaceAcrossTheFlip() {
    let start = StudyCardPresentation(progress: 0, reduceMotion: false)
    let beforeMidpoint = StudyCardPresentation(progress: 0.49, reduceMotion: false)
    let midpoint = StudyCardPresentation(progress: 0.5, reduceMotion: false)
    let afterMidpoint = StudyCardPresentation(progress: 0.51, reduceMotion: false)
    let end = StudyCardPresentation(progress: 1, reduceMotion: false)

    #expect(start.visibleFace == .front)
    #expect(start.frontOpacity == 1 && start.backOpacity == 0)
    #expect(beforeMidpoint.frontOpacity == 1 && beforeMidpoint.backOpacity == 0)
    #expect(midpoint.frontOpacity == 0 && midpoint.backOpacity == 1)
    #expect(afterMidpoint.frontOpacity == 0 && afterMidpoint.backOpacity == 1)
    #expect(end.visibleFace == .back)
    #expect(end.frontOpacity == 0 && end.backOpacity == 1)
}

@Test func reducedMotionFadesOutBeforeTheVisibleFaceChanges() {
    let firstHalf = StudyCardPresentation(progress: 0.25, reduceMotion: true)
    let midpoint = StudyCardPresentation(progress: 0.5, reduceMotion: true)
    let secondHalf = StudyCardPresentation(progress: 0.75, reduceMotion: true)

    #expect(firstHalf.frontOpacity == 0.5 && firstHalf.backOpacity == 0)
    #expect(midpoint.frontOpacity == 0 && midpoint.backOpacity == 0)
    #expect(secondHalf.frontOpacity == 0 && secondHalf.backOpacity == 0.5)
    #expect(firstHalf.frontOpacity * firstHalf.backOpacity == 0)
    #expect(secondHalf.frontOpacity * secondHalf.backOpacity == 0)
}

@Test func changingCardsResetsFacesWithoutAnimatingTheNextAnswerOut() {
    let revealedFirstCard = StudyCardPresentation(
        cardID: .fixture(1),
        isShowingAnswer: true,
        reduceMotion: false
    )
    let nextPrompt = StudyCardPresentation(
        cardID: .fixture(2),
        isShowingAnswer: false,
        reduceMotion: false
    )
    let firstPrompt = StudyCardPresentation(
        cardID: .fixture(1),
        isShowingAnswer: false,
        reduceMotion: false
    )
    let reducedPrompt = StudyCardPresentation(
        cardID: .fixture(1),
        isShowingAnswer: false,
        reduceMotion: true
    )

    #expect(revealedFirstCard.viewIdentity == .fixture(1))
    #expect(nextPrompt.viewIdentity == .fixture(2))
    #expect(firstPrompt.animationStyle == .flip3D)
    #expect(reducedPrompt.animationStyle == .crossfade)
}

@Test func cardContentFollowsDirectionAndExcludesUsageExamples() {
    let card = VocabularyCard.fixture(
        id: 1,
        russian: "слово",
        english: "word",
        ipa: "/wɜːd/",
        partsOfSpeech: [.noun, .verb],
        usageExamples: [
            UsageExample(
                id: .fixture(3_001),
                text: "This word matters.",
                partOfSpeech: .noun
            ),
            UsageExample(
                id: .fixture(3_002),
                text: "They worded it carefully.",
                partOfSpeech: .verb
            ),
        ]
    )
    let russianToEnglish = StudyCardContent(card: card, direction: .russianToEnglish)
    let englishToRussian = StudyCardContent(card: card, direction: .englishToRussian)

    #expect(russianToEnglish.front.language == .russian)
    #expect(russianToEnglish.front.values == ["слово"])
    #expect(russianToEnglish.back.language == .english)
    #expect(russianToEnglish.back.values == ["word"])
    #expect(russianToEnglish.back.englishMetadata == ["/wɜːd/", "noun, verb"])
    #expect(englishToRussian.front == russianToEnglish.back)
    #expect(englishToRussian.back == russianToEnglish.front)
}

private let configurationWithUsageExamples = StudyConfiguration(
    direction: .russianToEnglish,
    selectedTagIDs: [],
    cards: [
        .fixture(id: 1, usageExamples: [
            UsageExample(
                id: .fixture(3_001),
                text: "This word is useful.",
                partOfSpeech: .noun
            ),
        ]),
        .fixture(id: 2),
    ]
)

@MainActor
private func makeSession(
    configuration: StudyConfiguration = .fixture,
    speech: SpeechServiceSpy = SpeechServiceSpy(),
    feedback: StudyFeedbackSpy = StudyFeedbackSpy(),
    store: (any StudySessionStore)? = nil,
    now: @escaping @MainActor () -> Date = { Date(timeIntervalSince1970: 1_000) }
) -> StudySessionViewModel {
    StudySessionViewModel(
        configuration: configuration,
        shuffler: IdentityShuffler(),
        speech: speech,
        feedback: feedback,
        store: store,
        now: now
    )
}
