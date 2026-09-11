@MainActor
public protocol StudySessionStore: AnyObject, Sendable {
    func load() -> StudySessionSnapshot?
    func save(_ snapshot: StudySessionSnapshot)
    func clear()
}
