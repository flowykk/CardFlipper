import Core
import Foundation

@MainActor
public final class UserDefaultsStudySessionStore: StudySessionStore {
    public static let storageKey = "study.interruptedSession"

    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = UserDefaultsStudySessionStore.storageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func load() -> StudySessionSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }

        do {
            let decoder = JSONDecoder()
            let persistedVersion = try decoder.decode(PersistedVersion.self, from: data).version
            let snapshot = try decoder.decode(StudySessionSnapshot.self, from: data)
            guard snapshot.version == StudySessionSnapshot.currentVersion else {
                clear()
                return nil
            }
            if persistedVersion == 1 {
                save(snapshot)
            }
            return snapshot
        } catch {
            clear()
            return nil
        }
    }

    public func save(_ snapshot: StudySessionSnapshot) {
        guard snapshot.version == StudySessionSnapshot.currentVersion,
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    public func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    private struct PersistedVersion: Decodable {
        let version: Int
    }
}
