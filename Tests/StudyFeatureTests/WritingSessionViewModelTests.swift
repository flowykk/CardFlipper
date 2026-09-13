import Core
import Foundation
import Testing
@testable import StudyFeature

@MainActor
@Test func writingModelKeepsIncorrectAnswerAndClearsFeedbackWhenEdited() {
    let model = makeWritingSession()

    model.setResponse("wrong")
    model.checkResponse()

    #expect(model.response == "wrong")
    #expect(model.evaluation == .incorrect)
    #expect(model.canAssess == false)

    model.setResponse("word")

    #expect(model.evaluation == .unanswered)
    #expect(model.canCheck)
}

@MainActor
@Test func writingModelAcceptsCorrectAnswerAndRemembersOnlyOnRequest() throws {
    let feedback = StudyFeedbackSpy()
    let model = makeWritingSession(feedback: feedback)
    let firstID = StudyConfiguration.fixture.cards[0].id

    model.setResponse(" FIRST ")
    model.checkResponse()

    #expect(model.evaluation == .correct)
    #expect(model.session.currentCard?.id == firstID)
    #expect(model.canAssess)

    try model.remember()

    #expect(model.session.currentCard?.id == StudyConfiguration.fixture.cards[1].id)
    #expect(model.response.isEmpty)
    #expect(feedback.events == [.remember])
}

@MainActor
@Test func revealingWritingAnswerMarksDifficultAndUnlocksMetadataSpeech() {
    let speech = SpeechServiceSpy()
    let feedback = StudyFeedbackSpy()
    let model = makeWritingSession(
        configuration: .singleCard,
        speech: speech,
        feedback: feedback
    )
    let variant = StudyConfiguration.singleCard.cards[0].englishVariants[0]

    model.speakEnglish(variantID: variant.id)
    model.toggleAnswer()
    model.speakEnglish(variantID: variant.id)

    #expect(model.isShowingAnswer)
    #expect(model.difficultCards.map(\.id) == [StudyConfiguration.singleCard.cards[0].id])
    #expect(speech.spokenTexts == ["word"])
    #expect(feedback.events == [.reveal])
}

@MainActor
@Test func writingUsageExamplesRequireRevealedAnswerAndExpandedDisclosure() {
    let speech = SpeechServiceSpy()
    let model = makeWritingSession(
        configuration: configurationWithUsageExamples,
        speech: speech
    )
    let variant = configurationWithUsageExamples.cards[0].englishVariants[0]
    let example = variant.usageExamples[0]

    model.toggleUsageExamples()
    model.speakUsageExample(variantID: variant.id, exampleID: example.id)
    model.toggleAnswer()
    model.toggleUsageExamples()
    model.speakUsageExample(variantID: variant.id, exampleID: example.id)

    #expect(model.isShowingUsageExamples)
    #expect(speech.spokenTexts == [example.text])
}

@MainActor
@Test func writingCompletionBuildsSharedResultAndRepeatConfiguration() throws {
    var instant = Date(timeIntervalSince1970: 100)
    let feedback = StudyFeedbackSpy()
    let model = makeWritingSession(
        configuration: .singleCard,
        feedback: feedback,
        now: { instant }
    )

    model.toggleAnswer()
    model.toggleAnswer()
    model.setResponse("word")
    model.checkResponse()
    instant = instant.addingTimeInterval(9)
    try model.remember()

    #expect(model.result == StudyResult(
        reviewedCardCount: 1,
        repeatedCardIDs: [StudyConfiguration.singleCard.cards[0].id],
        totalAssessmentCount: 2,
        elapsedSeconds: 9
    ))
    #expect(model.difficultRepeatConfiguration?.mode == .writing)
    #expect(model.difficultRepeatConfiguration?.cards == StudyConfiguration.singleCard.cards)
    #expect(feedback.events == [.reveal, .reveal, .remember, .completion])
}

@MainActor
@Test func writingModelForgetsCorrectAnswerByRequeueingAndClearingInput() throws {
    let feedback = StudyFeedbackSpy()
    let model = makeWritingSession(feedback: feedback)
    let firstID = StudyConfiguration.fixture.cards[0].id

    model.setResponse("first")
    model.checkResponse()
    try model.forget()

    #expect(model.session.queue.map(\.id) == [
        StudyConfiguration.fixture.cards[1].id,
        firstID,
    ])
    #expect(model.response.isEmpty)
    #expect(model.evaluation == .unanswered)
    #expect(model.difficultCards.map(\.id) == [firstID])
    #expect(feedback.events == [.remember, .forget])
}

@MainActor
@Test func writingSnapshotRestoresResponseEvaluationFaceAndQueueWithoutShuffling() {
    let store = StudySessionStoreSpy()
    let snapshot = StudySessionSnapshot(
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagIDs: StudyConfiguration.fixture.selectedTagIDs,
        originalCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        queueCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        isShowingAnswer: true,
        isRevealed: true,
        forgottenCount: 1,
        repeatedCardIDs: [StudyConfiguration.fixture.cards[0].id],
        totalAssessmentCount: 1,
        writingResponse: "wrong",
        writingEvaluation: .incorrect,
        accumulatedDurationSeconds: 12
    )
    let shuffler = CountingShuffler()

    let model = WritingSessionViewModel(
        configuration: StudyConfiguration.fixture.writing,
        snapshot: snapshot,
        shuffler: shuffler,
        speech: SpeechServiceSpy(),
        store: store
    )

    #expect(model.response == "wrong")
    #expect(model.evaluation == .incorrect)
    #expect(model.isShowingAnswer)
    #expect(model.session.hasRevealedAnswer)
    #expect(shuffler.invocationCount == 0)
    #expect(store.storedSnapshot?.mode == .writing)
}

@MainActor
private func makeWritingSession(
    configuration: StudyConfiguration = .fixture.writing,
    speech: SpeechServiceSpy = SpeechServiceSpy(),
    feedback: StudyFeedbackSpy = StudyFeedbackSpy(),
    now: @escaping @MainActor () -> Date = { Date(timeIntervalSince1970: 1) }
) -> WritingSessionViewModel {
    WritingSessionViewModel(
        configuration: configuration,
        shuffler: IdentityShuffler(),
        speech: speech,
        feedback: feedback,
        now: now
    )
}

private extension StudyConfiguration {
    var writing: StudyConfiguration {
        StudyConfiguration(
            mode: .writing,
            direction: .russianToEnglish,
            selectedTagIDs: selectedTagIDs,
            cards: cards
        )
    }
}

private let configurationWithUsageExamples = StudyConfiguration(
    mode: .writing,
    direction: .russianToEnglish,
    selectedTagIDs: [],
    cards: [
        .fixture(
            id: 50,
            english: "write",
            usageExamples: [
                UsageExample(
                    id: .fixture(5_050),
                    text: "Please write your answer.",
                    partOfSpeech: .verb
                )
            ]
        )
    ]
)
