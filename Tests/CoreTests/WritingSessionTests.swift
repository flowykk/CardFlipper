import Foundation
import Testing
@testable import Core

private extension UUID {
    static func writingFixture(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, value))
    }
}

private func writingCard(
    id: UInt8 = 1,
    englishVariants: [String] = ["word"]
) -> VocabularyCard {
    VocabularyCard(
        id: .writingFixture(id),
        russianMeanings: [
            RussianMeaning(id: .writingFixture(id + 40), text: "слово")
        ],
        englishVariants: englishVariants.enumerated().map { index, text in
            EnglishVariant(
                id: .writingFixture(id + UInt8(index) + 80),
                text: text,
                ipa: nil,
                partsOfSpeech: []
            )
        },
        tags: [],
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1)
    )
}

@Test func writingAcceptsAnyEnglishVariantIgnoringCaseAndExtraWhitespace() {
    var session = WritingSession(cards: [
        writingCard(englishVariants: ["word", "multi word"])
    ])

    session.setResponse("  MULTI   Word ")
    let evaluation = session.checkResponse()

    #expect(evaluation == .correct)
    #expect(session.evaluation == .correct)
    #expect(session.totalAssessmentCount == 1)
}

@Test func constructingWritingSessionDoesNotEncounterCards() {
    let session = WritingSession(cards: [writingCard()])

    #expect(session.encounteredCardIDs.isEmpty)
}

@Test func checkingWritingResponseEncountersTheCurrentCard() {
    let card = writingCard()
    var session = WritingSession(cards: [card])

    session.setResponse("word")
    _ = session.checkResponse()

    #expect(session.encounteredCardIDs == [card.id])
}

@Test func firstWritingAnswerRevealEncountersTheCurrentCardOnlyOnce() {
    let card = writingCard()
    var session = WritingSession(cards: [card])

    session.toggleAnswer()
    session.toggleAnswer()
    session.toggleAnswer()

    #expect(session.encounteredCardIDs == [card.id])
}

@Test func incorrectWritingAttemptKeepsCardActiveAndMarksItDifficult() {
    let card = writingCard()
    var session = WritingSession(cards: [card])

    session.setResponse("wrong")
    #expect(session.checkResponse() == .incorrect)

    #expect(session.currentCard?.id == card.id)
    #expect(session.remainingCount == 1)
    #expect(session.forgottenCount == 1)
    #expect(session.repeatedCardIDs == [card.id])
    #expect(session.totalAssessmentCount == 1)
}

@Test func editingAfterIncorrectAttemptClearsOnlyTheEvaluation() {
    var session = WritingSession(cards: [writingCard()])
    session.setResponse("wrong")
    _ = session.checkResponse()

    session.setResponse("word")

    #expect(session.response == "word")
    #expect(session.evaluation == .unanswered)
    #expect(session.forgottenCount == 1)
}

@Test func revealingAnswerBeforeSuccessCountsOneHintAndNeverAdvances() {
    let card = writingCard()
    var session = WritingSession(cards: [card])

    session.toggleAnswer()
    session.toggleAnswer()
    session.toggleAnswer()

    #expect(session.currentCard?.id == card.id)
    #expect(session.isShowingAnswer)
    #expect(session.hasRevealedAnswer)
    #expect(session.forgottenCount == 1)
    #expect(session.repeatedCardIDs == [card.id])
    #expect(session.totalAssessmentCount == 1)
}

@Test func revealingAfterCorrectAnswerDoesNotMakeCardDifficult() {
    var session = WritingSession(cards: [writingCard()])
    session.setResponse("word")
    _ = session.checkResponse()

    session.toggleAnswer()

    #expect(session.isShowingAnswer)
    #expect(session.forgottenCount == 0)
    #expect(session.repeatedCardIDs.isEmpty)
    #expect(session.totalAssessmentCount == 1)
}

@Test func rememberRequiresCorrectAnswerAndResetsStateForFollowingCard() throws {
    var session = WritingSession(cards: [writingCard(id: 1), writingCard(id: 2)])

    #expect(throws: WritingSessionError.answerNotCorrect) {
        try session.remember()
    }

    session.setResponse("word")
    _ = session.checkResponse()
    try session.remember()

    #expect(session.currentCard?.id == .writingFixture(2))
    #expect(session.response.isEmpty)
    #expect(session.evaluation == .unanswered)
    #expect(session.isShowingAnswer == false)
    #expect(session.hasRevealedAnswer == false)
}

@Test func correctFinalAnswerCompletesOnlyAfterRemember() throws {
    var session = WritingSession(cards: [writingCard()])
    session.setResponse("word")
    _ = session.checkResponse()

    #expect(session.isComplete == false)
    try session.remember()
    #expect(session.isComplete)
}

@Test func forgettingCorrectAnswerMovesCardToQueueEndAndResetsWritingState() throws {
    let firstCard = writingCard(id: 1)
    let secondCard = writingCard(id: 2)
    var session = WritingSession(cards: [firstCard, secondCard])
    session.setResponse("word")
    _ = session.checkResponse()
    session.toggleAnswer()

    try session.forget()

    #expect(session.queue.map(\.id) == [secondCard.id, firstCard.id])
    #expect(session.response.isEmpty)
    #expect(session.evaluation == .unanswered)
    #expect(session.isShowingAnswer == false)
    #expect(session.hasRevealedAnswer == false)
    #expect(session.forgottenCount == 1)
    #expect(session.repeatedCardIDs == [firstCard.id])
    #expect(session.totalAssessmentCount == 2)
}
