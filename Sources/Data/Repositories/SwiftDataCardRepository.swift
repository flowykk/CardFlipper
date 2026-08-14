import Core
import Foundation
import SwiftData

@MainActor
public final class SwiftDataCardRepository: CardRepository {
    private let retainedContainer: ModelContainer
    private let context: ModelContext

    public init(container: ModelContainer) {
        retainedContainer = container
        context = container.mainContext
    }

    public func fetchCards() async throws -> [VocabularyCard] {
        let descriptor = FetchDescriptor<CardEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(VocabularyCardMapper.toDomain)
    }

    public func save(_ card: VocabularyCard) async throws {
        let tags = try fetchTags(ids: Set(card.tags.map(\.id)))

        if let entity = try fetchCard(id: card.id) {
            entity.russianMeanings.forEach(context.delete)
            entity.englishVariants.forEach(context.delete)
            VocabularyCardMapper.update(entity, from: card, tags: tags)
        } else {
            context.insert(VocabularyCardMapper.makeEntity(from: card, tags: tags))
        }
        try context.save()
    }

    public func addTags(ids: Set<UUID>, toCardIDs cardIDs: Set<UUID>) async throws {
        guard !ids.isEmpty, !cardIDs.isEmpty else { return }

        let tags = try fetchTags(ids: ids)
        let cards = try context.fetch(FetchDescriptor<CardEntity>())
            .filter { cardIDs.contains($0.id) }

        var didUpdate = false
        for card in cards {
            let existingIDs = Set(card.tags.map(\.id))
            let tagsToAppend = tags.filter { !existingIDs.contains($0.id) }
            guard !tagsToAppend.isEmpty else { continue }
            card.tags.append(contentsOf: tagsToAppend)
            didUpdate = true
        }
        guard didUpdate else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    public func delete(id: UUID) async throws {
        guard let card = try fetchCard(id: id) else { return }
        context.delete(card)
        try context.save()
    }

    public func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard] {
        let russianValues = Set(draft.russianMeanings.map(TextNormalizer.searchKey))
        let englishValues = Set(draft.englishVariants.map { TextNormalizer.searchKey($0.text) })

        return try await fetchCards().filter { card in
            guard card.id != id else { return false }

            let cardRussianValues = Set(card.russianMeanings.map { TextNormalizer.searchKey($0.text) })
            let cardEnglishValues = Set(card.englishVariants.map { TextNormalizer.searchKey($0.text) })
            return !cardRussianValues.isDisjoint(with: russianValues)
                || !cardEnglishValues.isDisjoint(with: englishValues)
        }
    }

    private func fetchCard(id: UUID) throws -> CardEntity? {
        let descriptor = FetchDescriptor<CardEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private func fetchTags(ids: Set<UUID>) throws -> [TagEntity] {
        guard !ids.isEmpty else { return [] }
        return try context.fetch(FetchDescriptor<TagEntity>())
            .filter { ids.contains($0.id) }
    }
}
