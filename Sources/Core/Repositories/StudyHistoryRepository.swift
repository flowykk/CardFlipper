@MainActor
public protocol StudyHistoryRepository: AnyObject {
    func fetchHistory() throws -> [StudyHistoryEntry]

    @discardableResult
    func insertIfNeeded(_ entry: StudyHistoryEntry) throws -> Bool
}
