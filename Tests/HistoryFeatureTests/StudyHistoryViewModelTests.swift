import Core
import Foundation
import HistoryFeature
import Testing

@MainActor
@Test func loadPublishesFetchedEntriesAndLoadedState() {
    let entry = StudyHistoryEntry.fixture(completedAt: Date(timeIntervalSince1970: 100))
    let model = StudyHistoryViewModel(
        repository: StudyHistoryRepositoryFake(fetchedEntries: [entry])
    )

    model.load()

    #expect(model.entries == [entry])
    #expect(model.state == .loaded)
}

@MainActor
@Test func loadPublishesEmptyCollectionAsLoaded() {
    let model = StudyHistoryViewModel(repository: StudyHistoryRepositoryFake())

    model.load()

    #expect(model.entries.isEmpty)
    #expect(model.state == .loaded)
}

@MainActor
@Test func failedLoadPublishesFailedStateWithoutStaleEntries() {
    let repository = StudyHistoryRepositoryFake(
        fetchedEntries: [.fixture(completedAt: Date(timeIntervalSince1970: 100))]
    )
    let model = StudyHistoryViewModel(repository: repository)
    model.load()
    repository.fetchError = HistoryTestError.fetch

    model.load()

    #expect(model.entries.isEmpty)
    #expect(model.state == .failed)
}

@MainActor
@Test func loadRetriesAfterFailureAndPublishesRecoveredEntries() {
    let recovered = StudyHistoryEntry.fixture(completedAt: Date(timeIntervalSince1970: 200))
    let repository = StudyHistoryRepositoryFake(fetchError: HistoryTestError.fetch)
    let model = StudyHistoryViewModel(repository: repository)
    model.load()
    repository.fetchError = nil
    repository.fetchedEntries = [recovered]

    model.load()

    #expect(model.entries == [recovered])
    #expect(model.state == .loaded)
}

@MainActor
@Test func loadOrdersHistoryNewestFirst() {
    let oldest = StudyHistoryEntry.fixture(completedAt: Date(timeIntervalSince1970: 100))
    let newest = StudyHistoryEntry.fixture(completedAt: Date(timeIntervalSince1970: 300))
    let middle = StudyHistoryEntry.fixture(completedAt: Date(timeIntervalSince1970: 200))
    let model = StudyHistoryViewModel(
        repository: StudyHistoryRepositoryFake(fetchedEntries: [oldest, newest, middle])
    )

    model.load()

    #expect(model.entries.map(\.id) == [newest.id, middle.id, oldest.id])
}
