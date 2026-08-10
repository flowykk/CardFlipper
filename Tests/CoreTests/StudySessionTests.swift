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
    #expect(session.forgottenCount == 1)
}

@Test func assessmentBeforeRevealIsRejected() {
    var session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)
    #expect(throws: StudySessionError.answerNotRevealed) { try session.remember() }
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
