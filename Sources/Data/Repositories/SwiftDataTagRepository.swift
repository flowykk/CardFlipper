import Core
import Foundation
import SwiftData

@MainActor
public final class SwiftDataTagRepository: TagRepository {
    private let retainedContainer: ModelContainer
    private let context: ModelContext

    public init(container: ModelContainer) {
        retainedContainer = container
        context = container.mainContext
    }

    public func fetchTags() async throws -> [Tag] {
        let descriptor = FetchDescriptor<TagEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).map { Tag(id: $0.id, name: $0.name) }
    }

    public func create(name: String) async throws -> Tag {
        if let existing = try fetchTag(name: name) {
            return Tag(id: existing.id, name: existing.name)
        }

        let entity = TagEntity(id: UUID(), name: name)
        context.insert(entity)
        try context.save()
        return Tag(id: entity.id, name: entity.name)
    }

    public func delete(id: UUID) async throws {
        guard let tag = try fetchTag(id: id) else { return }
        context.delete(tag)
        try context.save()
    }

    private func fetchTag(id: UUID) throws -> TagEntity? {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchTag(name: String) throws -> TagEntity? {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.name == name }
        )
        return try context.fetch(descriptor).first
    }
}
