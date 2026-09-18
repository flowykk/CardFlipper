import Core
import Data
import DesignSystem
import Foundation
import StudyFeature
import SwiftUI
import Testing
import UIKit
import StatisticsFeature
@testable import CardFlipper

@MainActor
@Test(arguments: [StudyMode.flashcards, .writing], ["saveAndExit", "finish", "repeat", "completion", "disappear"])
func callbacksFromEarlierPresentationCannotAffectResumedSession(mode: StudyMode, callback: String) async throws {
    let cards = [VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")]
    let store = AppStudySessionStoreFake()
    let history = AppHistoryRepositoryFake()
    let root = makeRootModel(cards: AppCardRepositoryFake(cards), studySessionStore: store, history: history)
    await root.loadLibrary()
    let configuration = StudyConfiguration(mode: mode, direction: .russianToEnglish, selectedTagIDs: [], cards: cards)
    root.requestStartStudy(configuration)
    let first = try #require(root.navigation.activeStudy)
    if mode == .writing { _ = root.makeWritingSessionModel(for: first) }
    else { _ = root.makeStudySessionModel(for: first) }
    root.saveAndExitStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    root.continueInterruptedStudy()
    let resumed = try #require(root.navigation.activeStudy)
    #expect(resumed.sessionID == first.sessionID)
    #expect(resumed.presentationID != first.presentationID)
    root.studyDidAppear(sessionID: resumed.sessionID, presentationID: resumed.presentationID)
    let saved = store.snapshot
    switch callback {
    case "saveAndExit": root.saveAndExitStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    case "finish": root.finishStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    case "repeat": root.repeatStudy(configuration, sessionID: first.sessionID, presentationID: first.presentationID)
    case "completion": root.recordCompletedStudy(sessionID: first.sessionID, presentationID: first.presentationID, mode: mode,
                                                  result: StudyResult(uniqueCardCount: 1, forgottenCount: 0))
    default: root.studyDidDisappear(sessionID: first.sessionID, presentationID: first.presentationID)
    }
    #expect(root.navigation.activeStudy == resumed)
    #expect(root.studyTimer.snapshot.isVisible)
    #expect(root.pendingStudyConfiguration == nil)
    #expect(root.resumableSnapshot == nil)
    #expect(store.snapshot == saved)
    #expect(history.entries.isEmpty)
}

@MainActor
@Test(arguments: [StudyMode.flashcards, .writing])
func staleAppearanceCannotStartTimerForResumedPresentation(mode: StudyMode) async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let root = makeRootModel(cards: AppCardRepositoryFake([card]))
    await root.loadLibrary()
    root.requestStartStudy(StudyConfiguration(mode: mode, direction: .russianToEnglish, selectedTagIDs: [], cards: [card]))
    let first = try #require(root.navigation.activeStudy)
    if mode == .writing { _ = root.makeWritingSessionModel(for: first) }
    else { _ = root.makeStudySessionModel(for: first) }
    root.saveAndExitStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    root.continueInterruptedStudy()
    root.studyDidAppear(sessionID: first.sessionID, presentationID: first.presentationID)
    #expect(!root.studyTimer.snapshot.isVisible)
}

@MainActor
@Test(arguments: [StudyMode.flashcards, .writing])
func departingFactoriesAndModelsCannotOverwriteSavedOrResumedProgress(mode: StudyMode) async throws {
    let cards = [VocabularyCard.appFixture(id: 1, russian: "слово", english: "word"),
                 VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")]
    let store = AppStudySessionStoreFake()
    let root = makeRootModel(cards: AppCardRepositoryFake(cards), studySessionStore: store)
    await root.loadLibrary()
    root.requestStartStudy(StudyConfiguration(mode: mode, direction: .russianToEnglish, selectedTagIDs: [], cards: cards))
    let first = try #require(root.navigation.activeStudy)
    let mutateOldModel: () throws -> Void
    let callOldFactory: () -> Void
    switch mode {
    case .flashcards:
        let model = root.makeStudySessionModel(for: first)
        model.toggleCardSide()
        try model.remember()
        mutateOldModel = { model.toggleCardSide(); model.persistSnapshot() }
        callOldFactory = { _ = root.makeStudySessionModel(for: first) }
    case .writing:
        let model = root.makeWritingSessionModel(for: first)
        model.setResponse("word")
        model.checkResponse()
        try model.remember()
        model.setResponse("saved draft")
        mutateOldModel = { model.setResponse("obsolete draft"); model.persistSnapshot() }
        callOldFactory = { _ = root.makeWritingSessionModel(for: first) }
    }
    root.saveAndExitStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    let saved = try #require(store.snapshot)
    #expect(saved.completedCardIDs == [cards[0].id])
    callOldFactory()
    #expect(store.snapshot == saved)
    #expect(root.resumableSnapshot == saved)
    try mutateOldModel()
    #expect(store.snapshot == saved)
    #expect(root.resumableSnapshot == saved)

    root.continueInterruptedStudy()
    let resumed = try #require(root.navigation.activeStudy)
    #expect(resumed.sessionID == first.sessionID)
    let verifyResumedModel: () -> Void
    switch mode {
    case .flashcards:
        let model = root.makeStudySessionModel(for: resumed)
        #expect(model.session.currentCard?.id == cards[1].id)
        #expect(model.rememberedCount == 1)
        model.toggleCardSide()
        verifyResumedModel = { #expect(root.makeStudySessionModel(for: resumed) === model) }
    case .writing:
        let model = root.makeWritingSessionModel(for: resumed)
        #expect(model.session.currentCard?.id == cards[1].id)
        #expect(model.session.response == "saved draft")
        model.setResponse("resumed draft")
        verifyResumedModel = { #expect(root.makeWritingSessionModel(for: resumed) === model) }
    }
    let current = store.snapshot
    callOldFactory()
    #expect(store.snapshot == current)
    try mutateOldModel()
    verifyResumedModel()
    #expect(store.snapshot == current)
    root.saveAndExitStudy(sessionID: resumed.sessionID, presentationID: resumed.presentationID)
    #expect(root.resumableSnapshot == current)
}

@MainActor
@Test(arguments: [StudyMode.flashcards, .writing])
func completedLegacyRecoveryAddsHistoryWithoutDuplicatingPreviouslyRecordedStatistics(mode: StudyMode) async throws {
    let suite = "App.completedLegacy.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("""
    {"version":1,"mode":"\(mode.rawValue)","direction":"englishToRussian",
     "selectedTagIDs":["00000000-0000-0000-0000-000000000700"],
     "originalCardIDs":["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002"],
     "queueCardIDs":[],"isShowingAnswer":false,"isRevealed":false,"forgottenCount":1,
     "repeatedCardIDs":["00000000-0000-0000-0000-000000000002"],"totalAssessmentCount":3,
     "startedAt":100,"accumulatedDurationSeconds":15,
     "completedResult":{"reviewedCardCount":2,"repeatedCardIDs":["00000000-0000-0000-0000-000000000002"],"totalAssessmentCount":3,"elapsedSeconds":15}}
    """.utf8), forKey: UserDefaultsStudySessionStore.storageKey)
    defaults.set(Data("""
    {"completedLessonCount":1,"studiedCardCount":2,"forgottenCount":1,
     "lessonsWithoutForgettingCount":0,"repeatedCardCount":1,"totalAssessmentCount":3,
     "writingCompletedLessonCount":\(mode == .writing ? 1 : 0),
     "writingStudiedCardCount":\(mode == .writing ? 2 : 0),
     "writingForgottenCount":\(mode == .writing ? 1 : 0),
     "writingRepeatedCardCount":\(mode == .writing ? 1 : 0),
     "writingTotalAssessmentCount":\(mode == .writing ? 3 : 0),"recordedSessionIDs":[]}
    """.utf8), forKey: "statistics.completedStudySessions.v1")
    let statistics = UserDefaultsStatisticsRepository(defaults: defaults)
    let originalStatistics = statistics.statistics
    #expect(originalStatistics.completedLessonCount == 1)
    #expect(originalStatistics.studiedCardCount == 2)
    #expect(originalStatistics.encounteredCardCount == 2)
    #expect(originalStatistics.firstTryRecallPercentage == 50)
    #expect(originalStatistics.writing.completedLessonCount == (mode == .writing ? 1 : 0))
    let history = AppHistoryRepositoryFake()
    history.fails = true
    let cards = AppCardRepositoryFake([.appFixture(id: 1, russian: "слово", english: "word"), .appFixture(id: 2, russian: "книга", english: "book")])
    let store = UserDefaultsStudySessionStore(defaults: defaults)
    let root = makeRootModel(cards: cards, studySessionStore: store, history: history, statistics: statistics,
                             tags: AppTagRepositoryFake([Tag(id: .appFixture(700), name: "Legacy tag")]))
    await root.loadLibrary()
    let retained = try #require(store.load())
    #expect(root.presentationError == .finalization(sessionID: retained.sessionID))
    #expect(statistics.statistics == originalStatistics)
    history.fails = false
    // A fresh root/store exercises the durable migration marker after a failed write and relaunch.
    let recovered = makeRootModel(cards: cards, studySessionStore: UserDefaultsStudySessionStore(defaults: defaults), history: history,
                                  statistics: UserDefaultsStatisticsRepository(defaults: defaults))
    await recovered.loadLibrary()
    let entry = try #require(history.entries.first)
    #expect(entry.id == retained.sessionID)
    #expect(entry.mode == mode)
    #expect(entry.plannedCardCount == 2)
    #expect(entry.completedCardCount == 2)
    #expect(entry.encounteredCardCount == 2)
    #expect(entry.recallRatePercentage == 50)
    #expect(entry.selectedTagNames == ["Legacy tag"])
    #expect(entry.difficultCardTitles == ["book"])
    #expect(store.load() == nil)
    #expect(UserDefaultsStatisticsRepository(defaults: defaults).statistics == originalStatistics)
    let finalizer = StudyHistoryFinalizer(history: history, statistics: statistics, sessionStore: store)
    _ = try finalizer.finalize(retained, completedAt: Date())
    #expect(history.entries.count == 1)
    #expect(statistics.statistics == originalStatistics)
}

@MainActor
@Test func legacyReplacementBackfillsProgressAndLabelsBeforeFinalizing() async throws {
    let snapshot = try StudySessionSnapshot.appLegacyFixture()
    let cards = [VocabularyCard.appFixture(id: 1, russian: "слово", english: "word"),
                 VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")]
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake(cards), studySessionStore: store, history: history,
                              tags: AppTagRepositoryFake([Tag(id: .appFixture(700), name: "Legacy tag")]))
    await model.loadLibrary()
    #expect(store.snapshot?.sessionID == snapshot.sessionID)
    model.requestStartStudy(StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: cards))
    model.replaceInterruptedStudy()
    let entry = try #require(history.entries.first)
    #expect(entry.completedCardCount == 1)
    #expect(entry.encounteredCardCount == 2)
    #expect(entry.repeatedCardCount == 1)
    #expect(entry.recallRatePercentage == 50)
    #expect(entry.selectedTagNames == ["Legacy tag"])
    #expect(entry.difficultCardTitles == ["book"])
}

@MainActor
@Test func legacyCompletionAfterResumePreservesPriorProgressAndCapturedLabels() async throws {
    let snapshot = try StudySessionSnapshot.appLegacyFixture()
    let cards = [VocabularyCard.appFixture(id: 1, russian: "слово", english: "word"),
                 VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")]
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake(cards), studySessionStore: store, history: history,
                              tags: AppTagRepositoryFake([Tag(id: .appFixture(700), name: "Legacy tag")]))
    await model.loadLibrary()
    model.continueInterruptedStudy()
    let active = try #require(model.navigation.activeStudy)
    let session = model.makeStudySessionModel(for: active)
    session.toggleCardSide()
    try session.remember()
    model.recordCompletedStudy(sessionID: active.sessionID, presentationID: active.presentationID, mode: .flashcards, result: try #require(session.result))
    #expect(history.entries.first?.completedCardCount == 2)
    #expect(history.entries.first?.encounteredCardCount == 2)
    #expect(history.entries.first?.repeatedCardCount == 1)
    #expect(history.entries.first?.selectedTagNames == ["Legacy tag"])
    #expect(history.entries.first?.difficultCardTitles == ["book"])
}

@MainActor
@Test func staleRepeatAndFinishCannotFinalizeOrDismissTheNextSession() async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let store = AppStudySessionStoreFake()
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history)
    await model.loadLibrary()
    let configuration = StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: [card])
    model.requestStartStudy(configuration)
    let first = try #require(model.navigation.activeStudy)
    let firstModel = model.makeStudySessionModel(for: first)
    firstModel.toggleCardSide()
    try firstModel.remember()
    model.recordCompletedStudy(sessionID: first.sessionID, presentationID: first.presentationID, mode: .flashcards, result: try #require(firstModel.result))
    model.repeatStudy(configuration, sessionID: first.sessionID, presentationID: first.presentationID)
    let second = try #require(model.navigation.activeStudy)
    let secondModel = model.makeStudySessionModel(for: second)
    model.studyDidAppear(sessionID: second.sessionID, presentationID: second.presentationID)
    let savedSecond = store.snapshot
    model.repeatStudy(configuration, sessionID: first.sessionID, presentationID: first.presentationID)
    model.finishStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    model.saveAndExitStudy(sessionID: first.sessionID, presentationID: first.presentationID)
    model.studyDidAppear(sessionID: first.sessionID, presentationID: first.presentationID)
    model.studyDidDisappear(sessionID: first.sessionID, presentationID: first.presentationID)
    #expect(model.navigation.activeStudy == second)
    #expect(model.makeStudySessionModel(for: second) === secondModel)
    #expect(store.snapshot == savedSecond)
    #expect(history.entries.count == 1)
    #expect(model.pendingStudyConfiguration == nil)
    #expect(model.studyTimer.snapshot.isVisible)
}

@MainActor
@Test func writingCorrectAnswerSavedBeforeRememberDoesNotCountAsForgotten() async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let store = AppStudySessionStoreFake()
    let history = AppHistoryRepositoryFake()
    let statistics = AppStatisticsSpy()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history, statistics: statistics)
    await model.loadLibrary()
    let configuration = StudyConfiguration(mode: .writing, direction: .russianToEnglish, selectedTagIDs: [], cards: [card])
    model.requestStartStudy(configuration)
    let active = try #require(model.navigation.activeStudy)
    let writing = model.makeWritingSessionModel(for: active)
    writing.setResponse("word")
    writing.checkResponse()
    model.saveAndExitStudy(sessionID: active.sessionID, presentationID: active.presentationID)
    model.requestStartStudy(configuration)
    model.replaceInterruptedStudy()
    #expect(history.entries.first?.completedCardCount == 0)
    #expect(history.entries.first?.encounteredCardCount == 1)
    #expect(history.entries.first?.totalAssessmentCount == 1)
    #expect(history.entries.first?.forgottenCount == 0)
    #expect(history.entries.first?.recallRatePercentage == 100)
    #expect(statistics.results.first?.forgottenCount == 0)
}

@MainActor
@Test func writingNaturalCompletionPreservesActualMistakesThroughSnapshotCoding() async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let store = AppStudySessionStoreFake()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store)
    await model.loadLibrary()
    model.requestStartStudy(StudyConfiguration(mode: .writing, direction: .russianToEnglish, selectedTagIDs: [], cards: [card]))
    let writing = model.makeWritingSessionModel(for: try #require(model.navigation.activeStudy))
    writing.setResponse("word")
    writing.checkResponse()
    try writing.forget()
    writing.setResponse("word")
    writing.checkResponse()
    try writing.remember()
    let restored = try JSONDecoder().decode(StudySessionSnapshot.self, from: JSONEncoder().encode(try #require(store.snapshot)))
    #expect(restored.completedResult?.forgottenCount == 1)
    #expect(restored.completedResult?.totalAssessmentCount == 3)
    #expect(restored.completedResult?.completedCardCount == 1)
}

@MainActor
@Test func deletingLastAvailableQueuedCardRefreshesBannerIntoHistory() async {
    let snapshot = StudySessionSnapshot.appHistoryFixture()
    let cards = AppCardRepositoryFake([.appFixture(id: 2, russian: "книга", english: "book")])
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: cards, studySessionStore: store, history: history)
    await model.loadLibrary()
    #expect(model.resumableSnapshot != nil)
    cards.fetchedCards = []
    await model.libraryChanged()
    #expect(model.resumableSnapshot == nil)
    #expect(store.snapshot == nil)
    #expect(history.entries.count == 1)
}

@MainActor
@Test func rootKeepsLiveModelsAcrossViewUpdatesAndRejectsWritesAfterFinalization() async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let store = AppStudySessionStoreFake()
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history)
    await model.loadLibrary()
    model.requestStartStudy(StudyConfiguration(mode: .writing, direction: .russianToEnglish, selectedTagIDs: [], cards: [card]))
    let active = try #require(model.navigation.activeStudy)
    let writing = model.makeWritingSessionModel(for: active)
    writing.setResponse("word")
    let refreshed = model.makeWritingSessionModel(for: active)
    #expect(refreshed === writing)
    #expect(store.snapshot?.writingResponse == "word")
    writing.checkResponse()
    try writing.remember()
    model.recordCompletedStudy(sessionID: active.sessionID, presentationID: active.presentationID, mode: .writing, result: try #require(writing.result))
    writing.persistSnapshot()
    _ = model.makeWritingSessionModel(for: active)
    #expect(store.snapshot == nil)
    #expect(history.entries.count == 1)
}

@MainActor
@Test func repeatWaitsForFailedNaturalCompletionBeforeStartingDistinctSession() async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let store = AppStudySessionStoreFake()
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history)
    await model.loadLibrary()
    let configuration = StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: [card])
    model.requestStartStudy(configuration)
    let active = try #require(model.navigation.activeStudy)
    let session = model.makeStudySessionModel(for: active)
    #expect(model.makeStudySessionModel(for: active) === session)
    session.toggleCardSide()
    try session.remember()
    history.fails = true
    model.recordCompletedStudy(sessionID: active.sessionID, presentationID: active.presentationID, mode: .flashcards, result: try #require(session.result))
    model.repeatStudy(configuration, sessionID: active.sessionID, presentationID: active.presentationID)
    #expect(model.navigation.activeStudy?.sessionID == active.sessionID)
    #expect(store.snapshot?.sessionID == active.sessionID)
    #expect(model.pendingStudyConfiguration == configuration)
    history.fails = false
    model.retryFinalization()
    let repeated = try #require(model.navigation.activeStudy)
    #expect(repeated.sessionID != active.sessionID)
    #expect(repeated.id == active.id)
    #expect(history.entries.count == 1)
    let newSession = model.makeStudySessionModel(for: repeated)
    session.persistSnapshot()
    #expect(store.snapshot?.sessionID == repeated.sessionID)
    #expect(newSession.result == nil)
}

@MainActor
@Test func deletedEncounteredQueuedCardNeverBecomesCompletedWhenFinalizedAfterResume() async throws {
    let snapshot = StudySessionSnapshot.appHistoryFixture(mode: .writing)
    let card = VocabularyCard.appFixture(id: 3, russian: "кот", english: "cat")
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history)
    await model.loadLibrary()
    model.continueInterruptedStudy()
    let active = try #require(model.navigation.activeStudy)
    _ = model.makeWritingSessionModel(for: active)
    model.saveAndExitStudy(sessionID: active.sessionID, presentationID: active.presentationID)
    model.requestStartStudy(StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: [card]))
    model.replaceInterruptedStudy()
    #expect(history.entries.first?.completedCardCount == 1)
    #expect(history.entries.first?.encounteredCardCount == 2)
    #expect(history.entries.first?.forgottenCount == 1)
}

@MainActor
@Test func launchRecoversCompletedSnapshotUsingSavedResultWithoutPresentingGame() async {
    let result = StudyResult(plannedCardCount: 3, completedCardCount: 2, encounteredCardIDs: [.appFixture(1), .appFixture(2)], repeatedCardIDs: [], totalAssessmentCount: 2, elapsedSeconds: 90)
    let snapshot = StudySessionSnapshot.appHistoryFixture(queue: [], completedResult: result)
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake(), studySessionStore: store, history: history)
    await model.loadLibrary()
    #expect(history.entries.first?.elapsedSeconds == 90)
    #expect(history.entries.first?.completedCardCount == 2)
    #expect(history.entries.first?.repeatedCardCount == 0)
    #expect(model.navigation.activeStudy == nil)
    #expect(model.resumableSnapshot == nil)
    #expect(store.snapshot == nil)
}

@MainActor
@Test func finalizerOrdersDurableWritesAndDerivesPartialProgressFromPersistedQueue() throws {
    let snapshot = StudySessionSnapshot.appHistoryFixture()
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let statistics = AppStatisticsSpy()
    var order: [String] = []
    history.onInsert = { order.append("history") }
    statistics.onRecord = { order.append("statistics") }
    store.onClear = { order.append("clear") }
    let finalizer = StudyHistoryFinalizer(history: history, statistics: statistics, sessionStore: store)

    let entry = try finalizer.finalize(snapshot, completedAt: Date(timeIntervalSince1970: 200))

    #expect(order == ["history", "statistics", "clear"])
    #expect(entry.id == snapshot.sessionID)
    #expect(entry.plannedCardCount == 3)
    #expect(entry.completedCardCount == 1)
    #expect(entry.encounteredCardCount == 2)
    #expect(entry.recallRatePercentage == 50)
    #expect(entry.forgottenCount == 1)
    #expect(entry.elapsedSeconds == 15)
    #expect(entry.difficultCardTitles == ["Original title"])
    #expect(entry.selectedTagNames == ["Original tag"])
    #expect(statistics.results.first?.completedCardCount == 1)
    #expect(store.snapshot == nil)
}

@MainActor
@Test func finalizerFailurePreservesSnapshotAndRetryRepairsAlreadyInsertedHistory() throws {
    let snapshot = StudySessionSnapshot.appHistoryFixture()
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let statistics = AppStatisticsSpy()
    let finalizer = StudyHistoryFinalizer(history: history, statistics: statistics, sessionStore: store)
    history.fails = true
    #expect(throws: AppTestError.self) {
        try finalizer.finalize(snapshot, completedAt: Date())
    }
    #expect(store.snapshot == snapshot)
    #expect(statistics.recordedIDs.isEmpty)
    history.fails = false
    let result = StudyResult(finalizing: snapshot)
    _ = try history.insertIfNeeded(StudyHistoryEntry(finalizing: snapshot, result: result, completedAt: Date()))
    _ = try finalizer.finalize(snapshot, completedAt: Date())
    _ = try finalizer.finalize(snapshot, completedAt: Date())
    #expect(history.entries.count == 1)
    #expect(statistics.recordedIDs == [snapshot.sessionID])
    #expect(store.snapshot == nil)
}

@MainActor
@Test func rootLaunchConflictContinueAndCancelPreserveSavedIdentity() async throws {
    let snapshot = StudySessionSnapshot.appHistoryFixture()
    let card = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store)
    let configuration = StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: [card])
    await model.loadLibrary()
    #expect(model.resumableSnapshot == snapshot)
    #expect(!model.isNewGameConflictPresented)
    #expect(model.presentationError == nil)
    model.requestStartStudy(configuration)
    #expect(model.pendingStudyConfiguration == configuration)
    #expect(model.isNewGameConflictPresented)
    #expect(model.navigation.activeStudy == nil)
    model.cancelPendingStudy()
    #expect(model.pendingStudyConfiguration == nil)
    #expect(model.resumableSnapshot == snapshot)
    model.requestStartStudy(configuration)
    model.continueInterruptedStudy()
    let active = try #require(model.navigation.activeStudy)
    #expect(active.sessionID == snapshot.sessionID)
    #expect(active.id == snapshot.sessionID)
    #expect(model.pendingStudyConfiguration == nil)
    #expect(!model.isNewGameConflictPresented)
    let session = model.makeStudySessionModel(for: active)
    session.persistSnapshot()
    #expect(store.snapshot?.sessionID == snapshot.sessionID)
}

@MainActor
@Test func rootReplacementWaitsForSuccessfulFinalizationAndRetainsPendingChoiceOnFailure() async throws {
    let snapshot = StudySessionSnapshot.appHistoryFixture()
    let card = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history)
    let configuration = StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: [card])
    await model.loadLibrary()
    model.requestStartStudy(configuration)
    history.fails = true
    model.replaceInterruptedStudy()
    #expect(model.navigation.activeStudy == nil)
    #expect(store.snapshot == snapshot)
    #expect(model.pendingStudyConfiguration == configuration)
    #expect(model.presentationError != nil)
    history.fails = false
    model.retryFinalization()
    let active = try #require(model.navigation.activeStudy)
    #expect(active.configuration == configuration)
    #expect(active.sessionID != snapshot.sessionID)
    #expect(model.pendingStudyConfiguration == nil)
    #expect(model.presentationError == nil)
    #expect(history.entries.count == 1)
    #expect(store.snapshot == nil)
}

@MainActor
@Test func rootCloseKeepsSnapshotAndNaturalCompletionFinalizesOnceWithoutDismissingResults() async throws {
    let card = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let store = AppStudySessionStoreFake()
    let history = AppHistoryRepositoryFake()
    let statistics = AppStatisticsSpy()
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store, history: history, statistics: statistics)
    await model.loadLibrary()
    model.requestStartStudy(StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: [card]))
    let active = try #require(model.navigation.activeStudy)
    let session = model.makeStudySessionModel(for: active)
    #expect(store.snapshot?.sessionID == active.sessionID)
    model.studyDidAppear(sessionID: active.sessionID, presentationID: active.presentationID)
    model.saveAndExitStudy(sessionID: active.sessionID, presentationID: active.presentationID)
    #expect(!model.studyTimer.snapshot.isVisible)
    #expect(store.snapshot != nil)
    #expect(model.resumableSnapshot?.sessionID == active.sessionID)
    #expect(model.navigation.activeStudy == nil)
    #expect(history.entries.isEmpty)
    model.continueInterruptedStudy()
    let resumed = try #require(model.navigation.activeStudy)
    let resumedSession = model.makeStudySessionModel(for: resumed)
    #expect(resumedSession !== session)
    resumedSession.toggleCardSide()
    try resumedSession.remember()
    let result = try #require(resumedSession.result)
    model.recordCompletedStudy(sessionID: resumed.sessionID, presentationID: resumed.presentationID, mode: .flashcards, result: result)
    model.recordCompletedStudy(sessionID: resumed.sessionID, presentationID: resumed.presentationID, mode: .flashcards, result: result)
    #expect(history.entries.count == 1)
    #expect(history.entries.first?.completedCardCount == 1)
    #expect(statistics.recordedIDs == [active.sessionID])
    #expect(model.navigation.activeStudy != nil)
    #expect(store.snapshot == nil)
    #expect(model.resumableSnapshot == nil)
}

@MainActor
@Test func recoveryFinalizationFailureRetainsSnapshotAndCanRetry() async {
    let snapshot = StudySessionSnapshot.appHistoryFixture()
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let history = AppHistoryRepositoryFake()
    history.fails = true
    let model = makeRootModel(cards: AppCardRepositoryFake(), studySessionStore: store, history: history)
    await model.loadLibrary()
    #expect(store.snapshot == snapshot)
    #expect(model.presentationError != nil)
    history.fails = false
    model.retryFinalization()
    #expect(store.snapshot == nil)
    #expect(history.entries.first?.completedCardCount == 1)
    #expect(history.entries.first?.plannedCardCount == 3)
}

@MainActor
@Test func writingResumeSkipsDeletedCurrentCardWithoutTransferringItsAnswer() async throws {
    let snapshot = StudySessionSnapshot.appHistoryFixture(mode: .writing)
    let card = VocabularyCard.appFixture(id: 3, russian: "кот", english: "cat")
    let store = AppStudySessionStoreFake(snapshot: snapshot)
    let model = makeRootModel(cards: AppCardRepositoryFake([card]), studySessionStore: store)
    await model.loadLibrary()
    model.continueInterruptedStudy()
    let active = try #require(model.navigation.activeStudy)
    let writing = model.makeWritingSessionModel(for: active)
    #expect(writing.session.currentCard?.id == card.id)
    #expect(writing.response.isEmpty)
    #expect(writing.evaluation == .unanswered)
    #expect(!writing.isShowingAnswer)
    #expect(!writing.canAssess)
    #expect(store.snapshot?.sessionID == snapshot.sessionID)
    #expect(store.snapshot?.completedCardIDs == [.appFixture(1)])
}

@Test func aiImportPromptExampleProducesAnImportableCard() throws {
    let data = try #require(CardImportAIPrompt.exampleJSON.data(using: .utf8))
    let document = try JSONDecoder().decode(CardTransferDocument.self, from: data)

    #expect(document.version == 1)
    #expect(document.decodedCards().count == 1)
    #expect(document.decodedCards().first?.russianMeanings.first?.text == "пример")
    #expect(document.decodedCards().first?.englishVariants.first?.text == "example")
}

@MainActor
@Test func editingImportedCardUpdatesThePreviewDraft() async throws {
    let original = VocabularyCard.appFixture(
        id: 1,
        russian: "слово",
        english: "word"
    )
    let model = try CardImportPreviewModel(
        preview: CardImportPreview(
            fileName: "cards.json",
            existing: [original],
            imported: [original]
        ),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake()
    )
    let editor = try #require(model.makeEditorModel(cardID: original.id))
    editor.russianMeanings[0].text = "термин"

    #expect(await editor.save() == .saved)
    await model.editorSaved()

    #expect(model.preview.changes.first?.card.russianMeanings.map(\.text) == ["термин"])
    #expect(model.preview.changes.first?.card.id == original.id)
    #expect(model.preview.changes.first?.kind == .updated)
    #expect(original.russianMeanings.map(\.text) == ["слово"])
}

@MainActor
@Test func importedTagsRemainAvailableWhileEditing() async throws {
    let tag = Tag(id: .appFixture(700), name: "Работа")
    let base = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let card = VocabularyCard(
        id: base.id,
        russianMeanings: base.russianMeanings,
        englishVariants: base.englishVariants,
        tags: [tag],
        createdAt: base.createdAt,
        updatedAt: base.updatedAt
    )
    let model = try CardImportPreviewModel(
        preview: CardImportPreview(fileName: "cards.json", existing: [], imported: [card]),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake()
    )
    let editor = try #require(model.makeEditorModel(cardID: card.id))

    await editor.loadTags()

    #expect(editor.availableTags == [tag])
    #expect(editor.selectedTagIDs == [tag.id])
}

@MainActor
@Test func importEditorDetectsDuplicatesAgainstUnaffectedLibraryCards() async throws {
    let existing = VocabularyCard.appFixture(id: 1, russian: "работа", english: "work")
    let imported = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let model = try CardImportPreviewModel(
        preview: CardImportPreview(
            fileName: "cards.json",
            existing: [existing],
            imported: [imported]
        ),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake()
    )
    let editor = try #require(model.makeEditorModel(cardID: imported.id))
    editor.russianMeanings[0].text = "работа"

    #expect(await editor.save() == .needsDuplicateConfirmation)
}

@MainActor
@Test func importEditorIncludesTagsWithoutCards() async throws {
    let orphanTag = Tag(id: .appFixture(700), name: "Архив")
    let imported = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let root = makeRootModel(
        cards: AppCardRepositoryFake(),
        tags: AppTagRepositoryFake([orphanTag])
    )
    let preview = try await root.makeImportPreviewModel([imported], fileName: "cards.json")
    let editor = try #require(preview.makeEditorModel(cardID: imported.id))

    await editor.loadTags()

    #expect(editor.availableTags == [orphanTag])
}

@MainActor
@Test func refreshedPreviewKeepsEditedReplacementIdentity() async throws {
    let original = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let cards = AppCardRepositoryFake([original])
    let root = makeRootModel(cards: cards)
    let model = try await root.makeImportPreviewModel([original], fileName: "cards.json")
    let editor = try #require(model.makeEditorModel(cardID: original.id))
    editor.russianMeanings[0].text = "термин"
    #expect(await editor.save() == .saved)
    await model.editorSaved()

    let refreshed = try await root.makeImportPreview(
        model.preview.importedCards,
        fileName: model.preview.fileName,
        replacingCardIDs: model.preview.replacingCardIDs
    )

    #expect(refreshed.changes.first?.card.id == original.id)
    #expect(refreshed.changes.first?.card.russianMeanings.map(\.text) == ["термин"])
    #expect(refreshed.changes.first?.kind == .updated)
}

@MainActor
@Test func confirmingImportPersistsTheEditedPreviewDraftOnlyOnce() async throws {
    let original = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let importer = AppCardImportRepositoryFake()
    importer.result = CardMergeResult(cards: [original], addedCount: 0, mergedCount: 1)
    let root = RootViewModel(
        cards: AppCardRepositoryFake([original]),
        cardImporter: importer,
        tags: AppTagRepositoryFake(),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake(),
        shuffler: AppIdentityShuffler(),
        history: AppHistoryRepositoryFake()
    )
    let preview = try await root.makeImportPreviewModel([original], fileName: "cards.json")
    let editor = try #require(preview.makeEditorModel(cardID: original.id))
    editor.russianMeanings[0].text = "термин"
    #expect(await editor.save() == .saved)
    await preview.editorSaved()

    try await root.confirmImport(preview.preview)

    #expect(importer.importedCards.count == 1)
    #expect(importer.importCallCount == 1)
    #expect(importer.replacingCardIDs == [original.id])
    #expect(importer.importedCards.first?.russianMeanings.map(\.text) == ["термин"])
}

@MainActor
@Test func appOffersTenIconsWithLoadablePreviewsAndDeclaredAlternates() throws {
    #expect(AppIconSettings.AppIcon.allCases.count == 10)
    let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
    let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: [String: Any]])
    for icon in AppIconSettings.AppIcon.allCases {
        let preview = icon == .default ? "Preview_AppIcon" : "Preview_\(icon.rawValue)"
        #expect(UIImage(named: preview) != nil, "Missing preview: \(preview)")
        if let name = icon.alternateIconName {
            let entry = try #require(alternates[name])
            #expect(entry["CFBundleIconName"] as? String == name)
        }
    }
}

@Test func appDeclaresAModernLaunchScreenToAvoidLegacyLetterboxing() {
    #expect(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") != nil)
}

@MainActor
@Test func appearanceSettingsDefaultToSystemAccent() throws {
    let suiteName = "AppearanceSettingsTests.default"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)
    let expected = try #require(lightSRGBComponents(of: Color(uiColor: .systemBlue)))

    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
}

@MainActor
@Test func appIconSettingsReadTheActualSystemSelection() {
    let settings = AppIconSettings()
    let expected = UIApplication.shared.alternateIconName
        .flatMap(AppIconSettings.AppIcon.init(rawValue:)) ?? .default
    #expect(settings.selectedIcon == expected)
}

@MainActor
@Test func appearanceSettingsPersistAndRestoreCustomAccent() throws {
    let suiteName = "AppearanceSettingsTests.persistence"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = AppearanceSettings(defaults: defaults)
    settings.accentColor = Color(.sRGB, red: 0.25, green: 0.5, blue: 0.75)

    let restored = AppearanceSettings(defaults: defaults)
    let components = try #require(restored.sRGBComponents)
    #expect(abs(components.red - 0.25) < 0.001)
    #expect(abs(components.green - 0.5) < 0.001)
    #expect(abs(components.blue - 0.75) < 0.001)
}

@MainActor
@Test func appearanceSettingsMigratesSelectedPresetToCustomColor() throws {
    let suiteName = "AppearanceSettingsTests.migration"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("berry", forKey: AppearanceSettings.selectionKey)

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)
    let berry = try #require(AccessibleAccent.all.first { $0.id == "berry" })
    let expected = try #require(lightSRGBComponents(of: berry.lightColor))

    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
    #expect(defaults.data(forKey: AppearanceSettings.storageKey) != nil)
    #expect(defaults.string(forKey: AppearanceSettings.selectionKey) == nil)
}

@MainActor
@Test func appearanceSettingsRejectInvalidPersistedColor() throws {
    let suiteName = "AppearanceSettingsTests.invalid"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(Data("{\"red\":2}".utf8), forKey: AppearanceSettings.storageKey)

    let settings = AppearanceSettings(defaults: defaults)
    let components = try #require(settings.sRGBComponents)
    let expected = try #require(lightSRGBComponents(of: Color(uiColor: .systemBlue)))

    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
}

@MainActor
private func lightSRGBComponents(of color: Color) -> (red: Double, green: Double, blue: Double)? {
    guard
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let components = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        ).cgColor.converted(
            to: colorSpace,
            intent: .defaultIntent,
            options: nil
        )?.components,
        components.count >= 3
    else {
        return nil
    }

    return (
        red: Double(components[0]),
        green: Double(components[1]),
        blue: Double(components[2])
    )
}

@MainActor
@Test func openingSettingsAppendsTheSettingsRouteOnlyOnce() {
    let navigation = AppNavigationState()

    navigation.openSettings()
    navigation.openSettings()

    #expect(navigation.path == [.settings])
}

@Test func appUsesCardsFlipperAsItsDisplayName() {
    #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Cards Flipper")
}

#if DEBUG
@Test func studyHistoryLaunchFlagsAlwaysIsolateDataAndSeedPlayableVocabulary() {
    for flag in ["-uiTestHistory", "-uiTestResume"] {
        let configuration = AppLaunchConfiguration(arguments: [flag])
        #expect(configuration.usesInMemoryStore)
        #expect(configuration.seedsDeterministicVocabulary)
        #expect(configuration.seedsStudyHistory == (flag == "-uiTestHistory"))
        #expect(configuration.seedsResumableStudy == (flag == "-uiTestResume"))
    }
    let production = AppLaunchConfiguration(arguments: [])
    #expect(!production.seedsStudyHistory)
    #expect(!production.seedsResumableStudy)
    #expect(!production.usesInMemoryStore)
}

@Test func uiTestLaunchConfigurationSelectsIsolatedStoreAndSeed() {
    let configuration = AppLaunchConfiguration(arguments: [
        "CardFlipper",
        "-uiTesting",
        "-uiTestSeed",
    ])

    #expect(configuration.usesInMemoryStore)
    #expect(configuration.seedsDeterministicVocabulary)
    #expect(!configuration.preservesStudySession)
}

@Test func uiTestSeedCannotSelectThePersistentStore() {
    let configuration = AppLaunchConfiguration(arguments: [
        "CardFlipper",
        "-uiTestSeed",
    ])

    #expect(configuration.seedsDeterministicVocabulary)
    #expect(configuration.usesInMemoryStore)
}

@Test func partOfSpeechNamesResolveFromTheAppCatalogAtRuntime() {
    #expect(
        PartOfSpeech.noun.localizedName(locale: Locale(identifier: "en")) == "Noun"
    )
    #expect(
        PartOfSpeech.noun.localizedName(locale: Locale(identifier: "ru")) == "Существительное"
    )
}

@MainActor
@Test func seededUITestContainerContainsDeterministicCardsAndTags() async throws {
    let configuration = AppLaunchConfiguration(arguments: [
        "CardFlipper",
        "-uiTesting",
        "-uiTestSeed",
    ])
    let container = try AppContainer(configuration: configuration)

    let cards = try await container.cards.fetchCards()
    let tags = try await container.tags.fetchTags()

    #expect(cards.map(\.id) == AppLaunchConfiguration.seededCardIDs)
    #expect(cards.map { $0.russianMeanings.first?.text } == ["книга", "кот", "дом"])
    #expect(tags.map(\.name) == ["Основы", "Повторение"])
}
#endif

@MainActor
@Test func startupFailureCanRetryContainerConstruction() throws {
    var attempts = 0
    let startup = AppStartupState {
        attempts += 1
        if attempts == 1 {
            throw AppTestError.startup
        }
        return AppContainer(modelContainer: try ModelContainerFactory.makeInMemory())
    }

    #expect(startup.container == nil)
    #expect(startup.hasFailure)

    startup.retry()

    #expect(startup.container != nil)
    #expect(!startup.hasFailure)
    #expect(attempts == 2)
}

@MainActor
@Test func editorSaveReloadsLibraryThenDismissesPresentation() async {
    let original = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let updated = VocabularyCard.appFixture(id: 1, russian: "термин", english: "term")
    let cards = AppCardRepositoryFake([original])
    let model = makeRootModel(cards: cards)
    await model.loadLibrary()
    model.navigation.openEditor(cardID: original.id)
    cards.fetchedCards = [updated]

    await model.editorSaved()

    #expect(model.library.cards == [updated])
    #expect(model.navigation.editor == nil)
    #expect(cards.fetchCount == 2)
}

@MainActor
@Test func editorSelectionResolvesTheCurrentCardByIdentifier() async {
    let selected = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let other = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let cards = AppCardRepositoryFake([selected, other])
    let model = makeRootModel(cards: cards)
    await model.loadLibrary()

    model.navigation.openEditor(cardID: selected.id)

    #expect(model.selectedEditorCard == selected)
    #expect(model.navigation.editor?.cardID == selected.id)
}

@MainActor
@Test func rootModelExposesCurrentLibraryCardCount() async {
    let cards = AppCardRepositoryFake([
        .appFixture(id: 1, russian: "слово", english: "word"),
        .appFixture(id: 2, russian: "книга", english: "book")
    ])
    let model = makeRootModel(cards: cards)

    await model.loadLibrary()
    #expect(model.libraryCardCount == 2)

    cards.fetchedCards = []
    await model.loadLibrary()
    #expect(model.libraryCardCount == 0)
}

@MainActor
@Test func exportPreparationPropagatesRepositoryFailureWithoutCreatingDocument() async {
    let cards = AppCardRepositoryFake(fetchError: AppTestError.startup)
    let model = makeRootModel(cards: cards)
    var didFail = false

    do {
        _ = try await model.prepareExport()
    } catch {
        didFail = true
    }

    #expect(didFail)
    #expect(cards.fetchCount == 1)
}

@MainActor
@Test func exportPreparationReportsExactCardCount() async throws {
    let sourceCards = [
        VocabularyCard.appFixture(id: 1, russian: "слово", english: "word"),
        VocabularyCard.appFixture(id: 2, russian: "книга", english: "book"),
    ]
    let model = makeRootModel(cards: AppCardRepositoryFake(sourceCards))

    let prepared = try await model.prepareExport()

    #expect(prepared.cardCount == 2)
    #expect(prepared.document.transfer.decodedCards() == sourceCards)
}

@MainActor
@Test func activeStudyRepeatKeepsCoverPresentedWithFreshSessionIdentity() {
    let configuration = StudyConfiguration(
        direction: .englishToRussian,
        selectedTagIDs: [],
        cards: [.appFixture(id: 1, russian: "слово", english: "word")]
    )
    let navigation = AppNavigationState()
    navigation.path = [.studySetup]

    navigation.startStudy(configuration)
    let first = navigation.activeStudy
    navigation.repeatStudy(configuration)
    let repeated = navigation.activeStudy
    navigation.studyPresentationDidDismiss()

    #expect(first?.configuration == configuration)
    #expect(repeated?.configuration == configuration)
    #expect(first?.id == repeated?.id)
    #expect(first?.sessionID != repeated?.sessionID)
    #expect(navigation.path == [.studySetup])
    #expect(navigation.activeStudy != nil)
}

@MainActor
@Test func finishingOrAbandoningStudyReturnsToLibraryAndNewStateRestoresNoSession() {
    let configuration = StudyConfiguration(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        cards: [.appFixture(id: 1, russian: "слово", english: "word")]
    )
    let navigation = AppNavigationState()
    navigation.path = [.studySetup]
    navigation.startStudy(configuration)

    navigation.finishStudy()

    #expect(navigation.activeStudy == nil)
    #expect(navigation.path.isEmpty)
    #expect(AppNavigationState().activeStudy == nil)
}

@MainActor
@Test func loadingLibraryOffersAnInterruptedSessionWithMissingCardsRemoved() async throws {
    let first = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let second = VocabularyCard.appFixture(id: 2, russian: "книга", english: "book")
    let store = AppStudySessionStoreFake(snapshot: StudySessionSnapshot(
        direction: .englishToRussian,
        selectedTagIDs: [],
        originalCardIDs: [first.id, second.id],
        queueCardIDs: [first.id, second.id],
        isShowingAnswer: true,
        isRevealed: true,
        forgottenCount: 1,
        repeatedCardIDs: [first.id],
        totalAssessmentCount: 2,
        accumulatedDurationSeconds: 15
    ))
    let model = makeRootModel(
        cards: AppCardRepositoryFake([second]),
        studySessionStore: store
    )

    await model.loadLibrary()
    let resumable = try #require(model.resumableStudy)

    #expect(resumable.configuration.cards == [second])
    #expect(resumable.snapshot?.queueCardIDs == [first.id, second.id])

    model.resumeInterruptedStudy()
    #expect(model.navigation.activeStudy == resumable)
    #expect(model.resumableStudy == nil)
}

@MainActor
@Test func loadingLibraryRestoresWritingModeAndItsCurrentAnswer() async throws {
    let card = VocabularyCard.appFixture(id: 1, russian: "слово", english: "word")
    let snapshot = StudySessionSnapshot(
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: [card.id],
        queueCardIDs: [card.id],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 1,
        repeatedCardIDs: [card.id],
        totalAssessmentCount: 1,
        writingResponse: "wrong",
        writingEvaluation: .incorrect,
        accumulatedDurationSeconds: 5
    )
    let model = makeRootModel(
        cards: AppCardRepositoryFake([card]),
        studySessionStore: AppStudySessionStoreFake(snapshot: snapshot)
    )

    await model.loadLibrary()
    let study = try #require(model.resumableStudy)
    let writingModel = model.makeWritingSessionModel(for: study)

    #expect(study.configuration.mode == .writing)
    #expect(writingModel.response == "wrong")
    #expect(writingModel.evaluation == .incorrect)
}

@MainActor
@Test func emptyInterruptedSessionIsFinalized() async {
    let missingID = UUID.appFixture(999)
    let invalidStore = AppStudySessionStoreFake(snapshot: StudySessionSnapshot(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        originalCardIDs: [missingID],
        queueCardIDs: [missingID],
        isShowingAnswer: false,
        isRevealed: false,
        forgottenCount: 0,
        repeatedCardIDs: [],
        totalAssessmentCount: 0,
        accumulatedDurationSeconds: 0
    ))
    let history = AppHistoryRepositoryFake()
    let invalidModel = makeRootModel(
        cards: AppCardRepositoryFake(),
        studySessionStore: invalidStore,
        history: history
    )

    await invalidModel.loadLibrary()
    #expect(invalidModel.resumableStudy == nil)
    #expect(invalidStore.clearCount == 1)
    #expect(history.entries.count == 1)
    #expect(history.entries.first?.plannedCardCount == 1)
    #expect(history.entries.first?.completedCardCount == 0)
}

@MainActor
@Test func rootModelCoordinatesStudyTimerLifecycleIdempotently() {
    let defaults = UserDefaults(suiteName: "AppTimerLifecycle.\(UUID().uuidString)")!
    let progress = UserDefaultsDailyProgressRepository(defaults: defaults)
    let timer = StudyTimerController(progress: progress)
    let model = RootViewModel(
        cards: AppCardRepositoryFake(),
        cardImporter: AppCardImportRepositoryFake(),
        tags: AppTagRepositoryFake(),
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake(),
        shuffler: AppIdentityShuffler(),
        history: AppHistoryRepositoryFake(),
        dailyProgress: progress,
        studyTimer: timer
    )
    model.navigation.startStudy(StudyConfiguration(direction: .englishToRussian, selectedTagIDs: [], cards: []))
    let sessionID = model.navigation.activeStudy!.sessionID
    let presentationID = model.navigation.activeStudy!.presentationID

    model.sceneActivityChanged(isActive: true)
    model.studyDidAppear(sessionID: sessionID, presentationID: presentationID)
    #expect(timer.snapshot.isVisible)

    model.finishStudy(sessionID: sessionID, presentationID: presentationID)
    model.finishStudy(sessionID: sessionID, presentationID: presentationID)
    #expect(!timer.snapshot.isVisible)
}

@MainActor
private func makeRootModel(
    cards: AppCardRepositoryFake,
    studySessionStore: any StudySessionStore = AppStudySessionStoreFake(),
    history: any StudyHistoryRepository = AppHistoryRepositoryFake(),
    statistics: any StatisticsRepository = AppStatisticsSpy(),
    tags: any TagRepository = AppTagRepositoryFake()
) -> RootViewModel {
    RootViewModel(
        cards: cards,
        cardImporter: AppCardImportRepositoryFake(),
        tags: tags,
        dictionary: AppDictionaryServiceFake(),
        speech: AppSpeechServiceFake(),
        shuffler: AppIdentityShuffler(),
        history: history,
        statistics: statistics,
        studySessionStore: studySessionStore
    )
}

@MainActor
private final class AppIconClientStub: AppIconClient {
    var supportsAlternateIcons = true
    var alternateIconName: String?
    var fails = false
    var suspends = false
    var continuation: CheckedContinuation<Void, Never>?
    var requests: [String?] = []

    func changeIcon(to name: String?) async throws {
        requests.append(name)
        if suspends {
            await withCheckedContinuation { continuation = $0 }
        }
        if fails { throw AppTestError.startup }
        alternateIconName = name
    }
}

@MainActor
@Test func iconSelectionFollowsSystemStateAndCanReturnToPrimary() async {
    let client = AppIconClientStub()
    client.alternateIconName = "IconViolet3D"
    let settings = AppIconSettings(client: client)
    #expect(settings.selectedIcon == .violet3D)
    await settings.select(.mint3D)
    #expect(settings.selectedIcon == .mint3D)
    #expect(client.requests == ["IconMint3D"])
    await settings.select(.default)
    #expect(settings.selectedIcon == .default)
    #expect(client.requests.count == 2)
    #expect(client.requests.last! == nil)
    #expect(settings.errorMessage == nil)
    #expect(!settings.isChanging)
}

@MainActor
@Test func iconSelectionFailureKeepsCurrentIconAndAllowsRetry() async {
    let client = AppIconClientStub()
    client.fails = true
    let settings = AppIconSettings(client: client)
    await settings.select(.orange3D)
    #expect(settings.selectedIcon == .default)
    #expect(settings.errorMessage != nil)
    #expect(!settings.isChanging)
    client.fails = false
    await settings.select(.orange3D)
    #expect(settings.selectedIcon == .orange3D)
    #expect(settings.errorMessage == nil)
}

@MainActor
@Test func iconSelectionRejectsOverlappingRequests() async {
    let client = AppIconClientStub()
    client.suspends = true
    let settings = AppIconSettings(client: client)
    let first = Task { await settings.select(.violet3D) }
    for _ in 0..<100 where client.continuation == nil { await Task.yield() }
    #expect(settings.pendingIcon == .violet3D)
    #expect(settings.selectedIcon == .default)
    await settings.select(.orange3D)
    #expect(client.requests == ["IconViolet3D"])
    client.continuation?.resume()
    await first.value
    #expect(settings.selectedIcon == .violet3D)
    #expect(!settings.isChanging)
}

@MainActor
@Test func iconSelectionRefreshesExternalChangesAndSkipsUnavailableRequests() async {
    let client = AppIconClientStub()
    let settings = AppIconSettings(client: client)
    client.alternateIconName = "IconMidnight3D"
    settings.refreshSelection()
    #expect(settings.selectedIcon == .midnight3D)
    await settings.select(.midnight3D)
    #expect(client.requests.isEmpty)
    client.supportsAlternateIcons = false
    await settings.select(.mint3D)
    #expect(client.requests.isEmpty)
    #expect(settings.selectedIcon == .midnight3D)
    #expect(settings.errorMessage != nil)
}
