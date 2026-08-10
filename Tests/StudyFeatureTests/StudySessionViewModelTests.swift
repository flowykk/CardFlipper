import Core
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

    #expect(model.result == StudyResult(uniqueCardCount: 2, forgottenCount: 1))
    #expect(model.repeatConfiguration == .fixture)
    #expect(feedback.events == [
        .reveal,
        .forget,
        .reveal,
        .remember,
        .reveal,
        .completion,
    ])
}

@Test func resultPresentationMapsDontRememberActionsToExtraAttempts() {
    let presentation = StudyResultPresentation(
        result: StudyResult(uniqueCardCount: 3, forgottenCount: 2)
    )

    #expect(presentation.reviewedCards == StudyResultMetric(
        localizationKey: "study.result.cards",
        count: 3
    ))
    #expect(presentation.extraAttempts == StudyResultMetric(
        localizationKey: "study.result.extraAttempts",
        count: 2
    ))
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

@Test func cardContentFollowsDirectionAndIncludesEnglishMetadata() {
    let card = VocabularyCard.fixture(
        id: 1,
        russian: "слово",
        english: "word",
        ipa: "/wɜːd/",
        partsOfSpeech: [.noun, .verb]
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

@MainActor
private func makeSession(
    configuration: StudyConfiguration = .fixture,
    speech: SpeechServiceSpy = SpeechServiceSpy(),
    feedback: StudyFeedbackSpy = StudyFeedbackSpy()
) -> StudySessionViewModel {
    StudySessionViewModel(
        configuration: configuration,
        shuffler: IdentityShuffler(),
        speech: speech,
        feedback: feedback
    )
}
