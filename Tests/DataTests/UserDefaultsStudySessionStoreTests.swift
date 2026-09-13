import Core
import Foundation
import Testing
@testable import Data

@MainActor
@Test(arguments: [StudyMode.flashcards, .writing])
func literalCompletedVersionOneSnapshotSurvivesStoreMigration(mode: StudyMode) throws {
    let suite = "StudySessionStore.completedLegacy.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("""
    {"version":1,"mode":"\(mode.rawValue)","direction":"englishToRussian","selectedTagIDs":[],
     "originalCardIDs":["00000000-0000-0000-0000-000000000001"],"queueCardIDs":[],
     "isShowingAnswer":false,"isRevealed":false,"forgottenCount":1,
     "repeatedCardIDs":["00000000-0000-0000-0000-000000000001"],"totalAssessmentCount":2,
     "startedAt":100,"accumulatedDurationSeconds":15,
     "completedResult":{"reviewedCardCount":1,"repeatedCardIDs":["00000000-0000-0000-0000-000000000001"],"totalAssessmentCount":2,"elapsedSeconds":15}}
    """.utf8), forKey: UserDefaultsStudySessionStore.storageKey)
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let snapshot = try #require(store.load())
    let result = try #require(snapshot.completedResult)
    #expect(result == StudyResult(reviewedCardCount: 1, repeatedCardIDs: [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!], totalAssessmentCount: 2, elapsedSeconds: 15))
    #expect(result.plannedCardCount == 1)
    #expect(result.encounteredCardCount == 1)
    #expect(snapshot.mode == mode)
    #expect(snapshot.version == 2)
    #expect(snapshot.legacyCompletedStatisticsRecorded)
    #expect(store.load() == snapshot)
    #expect(try JSONDecoder().decode(StudySessionSnapshot.self, from: JSONEncoder().encode(snapshot)) == snapshot)
}

@MainActor
@Test func incompleteVersionTwoSnapshotKeepsGeneratedIdentityAcrossLoads() throws {
    let suite = "StudySessionStore.incompleteV2.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data(#"{"version":2,"direction":"russianToEnglish","selectedTagIDs":[],"originalCardIDs":[],"queueCardIDs":[],"isShowingAnswer":false,"isRevealed":false,"forgottenCount":0,"repeatedCardIDs":[],"totalAssessmentCount":0,"accumulatedDurationSeconds":0}"#.utf8), forKey: UserDefaultsStudySessionStore.storageKey)
    let first = try #require(UserDefaultsStudySessionStore(defaults: defaults).load())
    let second = try #require(UserDefaultsStudySessionStore(defaults: defaults).load())
    #expect(first == second)
    let persisted = try #require(defaults.data(forKey: UserDefaultsStudySessionStore.storageKey))
    #expect(try JSONDecoder().decode(StudySessionSnapshot.self, from: persisted) == first)
}

@MainActor
@Test func studySessionStoreRoundTripsVersionTwoSnapshotAndClearsIt() throws {
    let suiteName = "StudySessionStore.roundTrip.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let sessionID = UUID()
    let encounteredCardID = UUID()
    let pendingCardID = UUID()
    let displaySnapshot = StudyCardDisplaySnapshot(id: encounteredCardID, title: "Вопрос")
    let snapshot = StudySessionSnapshot(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: [encounteredCardID, pendingCardID],
        queueCardIDs: [pendingCardID],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 0,
        repeatedCardIDs: [],
        totalAssessmentCount: 0,
        accumulatedDurationSeconds: 12,
        sessionID: sessionID,
        lastActivityAt: Date(timeIntervalSince1970: 456),
        encounteredCardIDs: [encounteredCardID],
        completedCardIDs: [encounteredCardID],
        selectedTagNames: ["Русский"],
        cardDisplaySnapshots: [displaySnapshot]
    )

    store.save(snapshot)
    #expect(store.load() == snapshot)
    #expect(store.load()?.completedCardIDs == [encounteredCardID])

    store.clear()
    #expect(store.load() == nil)
}

@MainActor
@Test func studySessionStoreRoundTripsWritingModeVersionTwoSnapshot() throws {
    let suiteName = "StudySessionStore.writingRoundTrip.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let sessionID = UUID()
    let tagID = UUID()
    let cardID = UUID()
    let lastActivityAt = Date(timeIntervalSince1970: 456)
    let displaySnapshot = StudyCardDisplaySnapshot(id: cardID, title: "Написать ответ")
    let snapshot = StudySessionSnapshot(
        mode: .writing,
        direction: .englishToRussian,
        selectedTagIDs: [tagID],
        originalCardIDs: [cardID],
        queueCardIDs: [cardID],
        isShowingAnswer: true,
        isRevealed: true,
        forgottenCount: 1,
        repeatedCardIDs: [cardID],
        totalAssessmentCount: 2,
        writingResponse: "ответ",
        writingEvaluation: .incorrect,
        startedAt: Date(timeIntervalSince1970: 123),
        accumulatedDurationSeconds: 12,
        sessionID: sessionID,
        lastActivityAt: lastActivityAt,
        encounteredCardIDs: [cardID],
        completedCardIDs: [],
        selectedTagNames: ["Письмо"],
        cardDisplaySnapshots: [displaySnapshot]
    )

    store.save(snapshot)

    let loadedSnapshot = try #require(store.load())
    #expect(loadedSnapshot.mode == .writing)
    #expect(loadedSnapshot.writingResponse == "ответ")
    #expect(loadedSnapshot.writingEvaluation == .incorrect)
    #expect(loadedSnapshot.sessionID == sessionID)
    #expect(loadedSnapshot.lastActivityAt == lastActivityAt)
    #expect(loadedSnapshot.encounteredCardIDs == [cardID])
    #expect(loadedSnapshot.completedCardIDs.isEmpty)
    #expect(loadedSnapshot.selectedTagNames == ["Письмо"])
    #expect(loadedSnapshot.cardDisplaySnapshots == [displaySnapshot])
}

@MainActor
@Test func studySessionStoreDerivesCompletedCardsWhenVersionTwoFieldIsAbsent() throws {
    let suiteName = "StudySessionStore.missingCompletedCards.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let first = UUID()
    let pending = UUID()
    let third = UUID()
    let payload = """
    {"version":2,"direction":"russianToEnglish","selectedTagIDs":[],"originalCardIDs":["\(first.uuidString)","\(pending.uuidString)","\(third.uuidString)"],"queueCardIDs":["\(pending.uuidString)"],"isShowingAnswer":false,"isRevealed":false,"forgottenCount":0,"repeatedCardIDs":[],"totalAssessmentCount":2,"accumulatedDurationSeconds":0}
    """
    defaults.set(Data(payload.utf8), forKey: UserDefaultsStudySessionStore.storageKey)

    let snapshot = try #require(store.load())

    #expect(snapshot.completedCardIDs == [first, third])
}

@MainActor
@Test func studySessionStoreRejectsCorruptAndFutureSnapshots() throws {
    let suiteName = "StudySessionStore.validation.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)

    defaults.set(Data("not-json".utf8), forKey: UserDefaultsStudySessionStore.storageKey)
    #expect(store.load() == nil)
    #expect(defaults.data(forKey: UserDefaultsStudySessionStore.storageKey) == nil)

    let future = """
    {"version":999,"direction":"russianToEnglish","selectedTagIDs":[],"originalCardIDs":[],"queueCardIDs":[],"isShowingAnswer":false,"isRevealed":false,"forgottenCount":0,"repeatedCardIDs":[],"totalAssessmentCount":0,"accumulatedDurationSeconds":0}
    """
    defaults.set(Data(future.utf8), forKey: UserDefaultsStudySessionStore.storageKey)
    #expect(store.load() == nil)
    #expect(defaults.data(forKey: UserDefaultsStudySessionStore.storageKey) == nil)
}

@MainActor
@Test func studySessionStoreLoadsLegacySnapshotAsFlashcards() throws {
    let suiteName = "StudySessionStore.legacy.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let legacy = """
    {"version":1,"direction":"russianToEnglish","selectedTagIDs":[],"originalCardIDs":[],"queueCardIDs":[],"isShowingAnswer":false,"isRevealed":false,"forgottenCount":0,"repeatedCardIDs":[],"totalAssessmentCount":0,"startedAt":0,"accumulatedDurationSeconds":0}
    """
    defaults.set(Data(legacy.utf8), forKey: UserDefaultsStudySessionStore.storageKey)

    let snapshot = try #require(store.load())

    #expect(snapshot.mode == .flashcards)
    #expect(snapshot.writingResponse.isEmpty)
    #expect(snapshot.writingEvaluation == .unanswered)
    #expect(snapshot.version == StudySessionSnapshot.currentVersion)
    #expect(snapshot.lastActivityAt == snapshot.startedAt)
    #expect(snapshot.encounteredCardIDs.isEmpty)
    #expect(snapshot.completedCardIDs.isEmpty)
    #expect(snapshot.selectedTagNames.isEmpty)
    #expect(snapshot.cardDisplaySnapshots.isEmpty)

    let persistedSessionID = snapshot.sessionID
    let loadedAgain = try #require(store.load())
    #expect(loadedAgain.sessionID == persistedSessionID)
}
