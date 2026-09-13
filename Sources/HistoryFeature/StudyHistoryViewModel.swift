import Core
import Observation

public enum LoadingState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
public final class StudyHistoryViewModel {
    public private(set) var entries: [StudyHistoryEntry] = []
    public private(set) var state: LoadingState = .idle

    private let repository: any StudyHistoryRepository

    public init(repository: any StudyHistoryRepository) {
        self.repository = repository
    }

    public func load() {
        state = .loading

        do {
            entries = try repository.fetchHistory().sorted {
                $0.completedAt > $1.completedAt
            }
            state = .loaded
        } catch {
            entries = []
            state = .failed
        }
    }
}
