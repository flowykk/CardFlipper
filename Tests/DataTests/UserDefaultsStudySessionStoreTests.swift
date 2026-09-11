import Core
import Foundation
import Testing
@testable import Data

@MainActor
@Test func studySessionStoreRoundTripsAndClearsSnapshot() throws {
    let suiteName = "StudySessionStore.roundTrip.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsStudySessionStore(defaults: defaults)
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
        accumulatedDurationSeconds: 12
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
