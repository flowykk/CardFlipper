import Foundation
import Testing
@testable import Core

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
