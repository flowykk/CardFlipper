import Foundation

public protocol TagRepository: Sendable {
    @MainActor func fetchTags() async throws -> [Tag]
    @MainActor func create(name: String) async throws -> Tag
    @MainActor func delete(id: UUID) async throws
}
