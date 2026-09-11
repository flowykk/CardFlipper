import Foundation

public enum TagRepositoryError: Error, Equatable, Sendable {
    case emptyName
    case duplicateName(existingTagID: UUID)
    case tagNotFound
    case unsupportedMutation
}

public protocol TagRepository: Sendable {
    @MainActor func fetchTags() async throws -> [Tag]
    @MainActor func create(name: String) async throws -> Tag
    @MainActor func rename(id: UUID, name: String) async throws -> Tag
    @MainActor func merge(id: UUID, into destinationID: UUID) async throws
    @MainActor func delete(id: UUID) async throws
}

public extension TagRepository {
    @MainActor
    func rename(id: UUID, name: String) async throws -> Tag {
        throw TagRepositoryError.unsupportedMutation
    }

    @MainActor
    func merge(id: UUID, into destinationID: UUID) async throws {
        throw TagRepositoryError.unsupportedMutation
    }
}
