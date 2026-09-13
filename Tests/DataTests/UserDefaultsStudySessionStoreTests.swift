import Core
import Foundation
import Testing
@testable import Data

@MainActor
@Test func studySessionStoreRoundTripsVersionTwoSnapshotAndClearsIt() throws {
    let suiteName = "StudySessionStore.roundTrip.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let sessionID = UUID()
    let encounteredCardID = UUID()
    let displaySnapshot = StudyCardDisplaySnapshot(id: encounteredCardID, title: "Вопрос")
    let snapshot = StudySessionSnapshot(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: [UUID()],
        queueCardIDs: [UUID()],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 0,
        repeatedCardIDs: [],
        totalAssessmentCount: 0,
        accumulatedDurationSeconds: 12,
        sessionID: sessionID,
        lastActivityAt: Date(timeIntervalSince1970: 456),
        encounteredCardIDs: [encounteredCardID],
        selectedTagNames: ["Русский"],
        cardDisplaySnapshots: [displaySnapshot]
    )

    store.save(snapshot)
    #expect(store.load() == snapshot)

    store.clear()
    #expect(store.load() == nil)
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
    #expect(snapshot.selectedTagNames.isEmpty)
    #expect(snapshot.cardDisplaySnapshots.isEmpty)

    let persistedSessionID = snapshot.sessionID
    let loadedAgain = try #require(store.load())
    #expect(loadedAgain.sessionID == persistedSessionID)
}
