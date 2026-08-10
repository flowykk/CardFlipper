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
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = TextNormalizer.searchKey(displayName)
        if let existing = try fetchTag(normalizedName: normalizedName) {
            return Tag(id: existing.id, name: existing.name)
        }

        let entity = TagEntity(
            id: UUID(),
            name: displayName,
            normalizedName: normalizedName
        )
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

    private func fetchTag(normalizedName: String) throws -> TagEntity? {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.normalizedName == normalizedName }
        )
        return try context.fetch(descriptor).first
    }
}
