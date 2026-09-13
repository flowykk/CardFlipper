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
@Test func writingSnapshotCapturesStableMetadataAndAssessmentActivity() throws {
    let sessionID = UUID.fixture(9_101)
    let store = StudySessionStoreSpy()
    var instant = Date(timeIntervalSince1970: 300)
    let model = WritingSessionViewModel(
        configuration: .fixture.writing,
        sessionID: sessionID,
        selectedTagNames: ["Work"],
        shuffler: IdentityShuffler(),
        speech: SpeechServiceSpy(),
        feedback: StudyFeedbackSpy(),
        store: store,
        now: { instant }
    )

    let initialSnapshot = try #require(store.storedSnapshot)
    #expect(initialSnapshot.sessionID == sessionID)
    #expect(initialSnapshot.lastActivityAt == instant)
    #expect(initialSnapshot.selectedTagNames == ["Work"])
    #expect(initialSnapshot.cardDisplaySnapshots == [
        StudyCardDisplaySnapshot(id: .fixture(1), title: "first"),
        StudyCardDisplaySnapshot(id: .fixture(2), title: "second"),
    ])
    #expect(initialSnapshot.encounteredCardIDs.isEmpty)

    model.setResponse("wrong")
    instant = instant.addingTimeInterval(15)
    model.checkResponse()

    let assessedSnapshot = try #require(store.storedSnapshot)
    #expect(assessedSnapshot.lastActivityAt == instant)
    #expect(assessedSnapshot.encounteredCardIDs == [.fixture(1)])
}

@MainActor
@Test func resumedWritingSnapshotPreservesOriginalIdentityLabelsTitlesAndEncounters() {
    let originalSessionID = UUID.fixture(9_102)
    let originalDisplays = [
        StudyCardDisplaySnapshot(id: .fixture(1), title: "Historical first"),
        StudyCardDisplaySnapshot(id: .fixture(2), title: "Historical second"),
    ]
    let snapshot = StudySessionSnapshot(
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagIDs: [Tag.work.id],
        originalCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        queueCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 1,
        repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 1,
        accumulatedDurationSeconds: 20,
        sessionID: originalSessionID,
        encounteredCardIDs: [.fixture(1)],
        selectedTagNames: ["Historical tag"],
        cardDisplaySnapshots: originalDisplays
    )
    let editedConfiguration = StudyConfiguration(
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagIDs: [Tag.work.id],
        selectedTagNames: ["Edited tag"],
        cards: [
            .fixture(id: 1, english: "edited first"),
            .fixture(id: 2, english: "edited second"),
        ]
    )
    let store = StudySessionStoreSpy()

    let model = WritingSessionViewModel(
        configuration: editedConfiguration,
        sessionID: .fixture(9_999),
        selectedTagNames: editedConfiguration.selectedTagNames,
        snapshot: snapshot,
        shuffler: IdentityShuffler(),
        speech: SpeechServiceSpy(),
        feedback: StudyFeedbackSpy(),
        store: store,
        now: { Date(timeIntervalSince1970: 400) }
    )

    #expect(model.session.encounteredCardIDs == [.fixture(1)])
    #expect(model.repeatConfiguration.selectedTagNames == ["Historical tag"])
    #expect(store.storedSnapshot?.sessionID == originalSessionID)
    #expect(store.storedSnapshot?.selectedTagNames == ["Historical tag"])
    #expect(store.storedSnapshot?.cardDisplaySnapshots == originalDisplays)
}

@MainActor
@Test func resumedWritingCompletionKeepsPlannedCompletedAndEncounteredCountsSeparate() throws {
    let available = StudyConfiguration.fixture.cards[0]
    let snapshot = StudySessionSnapshot(
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: StudyConfiguration.fixture.cards.map(\.id),
        queueCardIDs: [available.id],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 0,
        repeatedCardIDs: [],
        totalAssessmentCount: 0,
        accumulatedDurationSeconds: 0
    )
    let model = WritingSessionViewModel(
        configuration: StudyConfiguration(
            mode: .writing,
            direction: .russianToEnglish,
            selectedTagIDs: [],
            cards: [available]
        ),
        snapshot: snapshot,
        shuffler: IdentityShuffler(),
        speech: SpeechServiceSpy(),
        feedback: StudyFeedbackSpy()
    )

    model.setResponse("first")
    model.checkResponse()
    try model.remember()

    #expect(model.result?.plannedCardCount == 2)
    #expect(model.result?.completedCardCount == 1)
    #expect(model.result?.encounteredCardCount == 1)
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
            selectedTagNames: selectedTagNames,
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
