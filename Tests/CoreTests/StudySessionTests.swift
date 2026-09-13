import Foundation
import Testing

@Test func legacyStudyResultDecodesWithoutExplicitMistakeCount() throws {
    let payload = Data("""
    {"plannedCardCount":3,"completedCardCount":2,"encounteredCardCount":2,
     "repeatedCardIDs":[],"totalAssessmentCount":4,"elapsedSeconds":15}
    """.utf8)
    let result = try JSONDecoder().decode(StudyResult.self, from: payload)
    #expect(result.forgottenCount == 2)
    #expect(result.completedCardCount == 2)
    #expect(result.elapsedSeconds == 15)
}
@testable import Core

@Test func literalOldStudyResultDecodesWithValidatedCountsAndSemanticEquality() throws {
    let payload = Data(#"{"reviewedCardCount":-2,"repeatedCardIDs":[],"totalAssessmentCount":-3,"elapsedSeconds":-4}"#.utf8)
    let result = try JSONDecoder().decode(StudyResult.self, from: payload)
    #expect(result == StudyResult(reviewedCardCount: 0, repeatedCardIDs: [], totalAssessmentCount: 0, elapsedSeconds: 0))
    #expect(result.plannedCardCount == 0)
    #expect(result.completedCardCount == 0)
    #expect(result.encounteredCardCount == 0)
}

@Test func currentStudyResultDecodingValidatesCountsAndPreservesExplicitMistakes() throws {
    let payload = Data(#"{"plannedCardCount":3,"completedCardCount":9,"encounteredCardCount":2,"repeatedCardIDs":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000001"],"totalAssessmentCount":4,"elapsedSeconds":-1,"recordedForgottenCount":1}"#.utf8)
    let result = try JSONDecoder().decode(StudyResult.self, from: payload)
    #expect(result.plannedCardCount == 3)
    #expect(result.completedCardCount == 2)
    #expect(result.encounteredCardCount == 2)
    #expect(result.repeatedCardCount == 1)
    #expect(result.elapsedSeconds == 0)
    #expect(result.forgottenCount == 1)
    #expect(result == StudyResult(plannedCardCount: 3, completedCardCount: 2,
        encounteredCardIDs: [.fixture(1), .fixture(2)], repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 4, elapsedSeconds: 0, forgottenCount: 1))
    #expect(try JSONDecoder().decode(StudyResult.self, from: JSONEncoder().encode(result)) == result)
}

private extension UUID {
    static func fixture(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private extension VocabularyCard {
    static func fixture(id: UInt8) -> VocabularyCard {
        fixture(id: UUID.fixture(id))
    }
}

@Test func rememberedCardLeavesQueue() throws {
    var session = StudySession(cards: [.fixture(id: 1), .fixture(id: 2)], direction: .russianToEnglish)
    session.reveal()
    try session.remember()
    #expect(session.currentCard?.id == .fixture(2))
    #expect(session.remainingCount == 1)
}

@Test func forgottenCardMovesToEndAndIncrementsCount() throws {
    var session = StudySession(cards: [.fixture(id: 1), .fixture(id: 2)], direction: .englishToRussian)
    session.reveal()
    try session.forget()
    #expect(session.currentCard?.id == .fixture(2))
    #expect(session.queue.map(\.id) == [.fixture(2), .fixture(1)])
    #expect(session.forgottenCount == 1)
    #expect(session.repeatedCardIDs == [.fixture(1)])
    #expect(session.totalAssessmentCount == 1)
}

@Test func repeatedCardIDsStayUniqueAcrossMultipleFailedAttempts() throws {
    var session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)
    session.reveal()
    try session.forget()
    session.reveal()
    try session.forget()
    session.reveal()
    try session.remember()

    #expect(session.repeatedCardIDs == [.fixture(1)])
    #expect(session.totalAssessmentCount == 3)
}

@Test func studyResultReportsRecallRateAndZeroRepeatCase() {
    let difficult = StudyResult(
        reviewedCardCount: 4,
        repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 6,
        elapsedSeconds: 125
    )
    let clean = StudyResult(
        reviewedCardCount: 3,
        repeatedCardIDs: [],
        totalAssessmentCount: 3,
        elapsedSeconds: 30
    )

    #expect(difficult.recallRatePercentage == 75)
    #expect(difficult.repeatedCardCount == 1)
    #expect(clean.recallRatePercentage == 100)
    #expect(clean.repeatedCardCount == 0)
}

@Test func studyResultUsesEncounteredCardsForPartialRecall() {
    let result = StudyResult(
        plannedCardCount: 10,
        completedCardCount: 3,
        encounteredCardIDs: [.fixture(1), .fixture(2), .fixture(3), .fixture(4)],
        repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 6,
        elapsedSeconds: 60
    )

    #expect(result.plannedCardCount == 10)
    #expect(result.completedCardCount == 3)
    #expect(result.encounteredCardCount == 4)
    #expect(result.recallRatePercentage == 75)
}

@Test func studyResultExcludesUnencounteredRepeatsFromPartialRecall() {
    let result = StudyResult(
        plannedCardCount: 10,
        completedCardCount: 6,
        encounteredCardIDs: [.fixture(1), .fixture(2), .fixture(3), .fixture(4)],
        repeatedCardIDs: [.fixture(1), .fixture(9), .fixture(9)],
        totalAssessmentCount: 7,
        elapsedSeconds: 60
    )

    #expect(result.completedCardCount == 4)
    #expect(result.repeatedCardIDs == [.fixture(1)])
    #expect(result.recallRatePercentage == 75)
}

@Test func constructingFlashcardSessionDoesNotEncounterCards() {
    let session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)

    #expect(session.encounteredCardIDs.isEmpty)
}

@Test func rememberingFlashcardEncountersTheCurrentCard() throws {
    var session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)

    session.reveal()
    try session.remember()

    #expect(session.encounteredCardIDs == [.fixture(1)])
}

@Test func forgettingFlashcardEncountersTheCurrentCard() throws {
    var session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)

    session.reveal()
    try session.forget()

    #expect(session.encounteredCardIDs == [.fixture(1)])
}

@Test func flashcardCompletionTracksOnlyCardsRemovedByRemembering() throws {
    var session = StudySession(
        cards: [.fixture(id: 1), .fixture(id: 2)],
        direction: .russianToEnglish
    )

    session.reveal()
    try session.forget()
    #expect(session.completedCardIDs.isEmpty)

    session.reveal()
    try session.remember()
    #expect(session.completedCardIDs == [.fixture(2)])
}

@Test func flashcardSessionRestoresCompletedCardIDs() {
    let session = StudySession(
        cards: [.fixture(id: 2)],
        direction: .russianToEnglish,
        initialCardCount: 2,
        forgottenCount: 1,
        encounteredCardIDs: [.fixture(1)],
        completedCardIDs: [.fixture(1)],
        repeatedCardIDs: [],
        totalAssessmentCount: 1,
        isRevealed: false
    )

    #expect(session.completedCardIDs == [.fixture(1)])
}

@Test func assessmentBeforeRevealIsRejected() {
    var rememberedSession = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)
    #expect(throws: StudySessionError.answerNotRevealed) { try rememberedSession.remember() }

    var forgottenSession = StudySession(cards: [.fixture(id: 1)], direction: .englishToRussian)
    #expect(throws: StudySessionError.answerNotRevealed) { try forgottenSession.forget() }
}

@Test func successfulAssessmentRequiresFreshReveal() throws {
    var rememberedSession = StudySession(cards: [.fixture(id: 1), .fixture(id: 2)], direction: .russianToEnglish)
    rememberedSession.reveal()
    try rememberedSession.remember()
    #expect(throws: StudySessionError.answerNotRevealed) { try rememberedSession.remember() }

    var forgottenSession = StudySession(cards: [.fixture(id: 1), .fixture(id: 2)], direction: .englishToRussian)
    forgottenSession.reveal()
    try forgottenSession.forget()
    #expect(throws: StudySessionError.answerNotRevealed) { try forgottenSession.forget() }
}

@Test func sessionCompletesOnlyAfterItsFinalCardIsRemembered() throws {
    var session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)
    #expect(session.isComplete == false)

    session.reveal()
    try session.remember()
    #expect(session.isComplete == true)
}

@Test func studySnapshotRoundTripsEveryRestorableField() throws {
    let result = StudyResult(
        reviewedCardCount: 2,
        repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 3,
        elapsedSeconds: 42
    )
    let snapshot = StudySessionSnapshot(
        mode: .writing,
        direction: .englishToRussian,
        selectedTagIDs: [.fixture(9)],
        originalCardIDs: [.fixture(1), .fixture(2)],
        queueCardIDs: [.fixture(1)],
        isShowingAnswer: true,
        isRevealed: true,
        forgottenCount: 1,
        repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 2,
        writingResponse: "answer",
        writingEvaluation: .incorrect,
        accumulatedDurationSeconds: 37,
        completedCardIDs: [.fixture(2)],
        completedResult: result
    )

    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(StudySessionSnapshot.self, from: data)

    #expect(decoded == snapshot)
    #expect(decoded.version == StudySessionSnapshot.currentVersion)
    #expect(decoded.completedCardIDs == [.fixture(2)])
}

@Test func sessionCanRestoreQueueAndCountersWithoutLosingAssessmentState() {
    let cards = [VocabularyCard.fixture(id: 2), .fixture(id: 1)]
    let session = StudySession(
        cards: cards,
        direction: .englishToRussian,
        initialCardCount: 3,
        forgottenCount: 2,
        repeatedCardIDs: [.fixture(1)],
        totalAssessmentCount: 4,
        isRevealed: true
    )

    #expect(session.queue.map(\.id) == [.fixture(2), .fixture(1)])
    #expect(session.initialCardCount == 3)
    #expect(session.forgottenCount == 2)
    #expect(session.repeatedCardIDs == [.fixture(1)])
    #expect(session.totalAssessmentCount == 4)
    #expect(session.isRevealed)
}

@Test func assessmentOfAnEmptySessionIsRejectedWithoutMutatingState() {
    var rememberedSession = StudySession(cards: [], direction: .russianToEnglish)
    rememberedSession.reveal()
    #expect(throws: StudySessionError.noCurrentCard) { try rememberedSession.remember() }
    #expect(rememberedSession.isRevealed)

    var forgottenSession = StudySession(cards: [], direction: .englishToRussian)
    forgottenSession.reveal()
    #expect(throws: StudySessionError.noCurrentCard) { try forgottenSession.forget() }
    #expect(forgottenSession.isRevealed)
    #expect(forgottenSession.forgottenCount == 0)
}
