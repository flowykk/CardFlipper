import Core
import Foundation
import SwiftData

@MainActor
public final class SwiftDataCardImportRepository: CardImportRepository {
    private let retainedContainer: ModelContainer
    private let beforeSave: @MainActor () throws -> Void

    public convenience init(container: ModelContainer) {
        self.init(container: container, beforeSave: {})
    }

    init(
        container: ModelContainer,
        beforeSave: @escaping @MainActor () throws -> Void
    ) {
        retainedContainer = container
        self.beforeSave = beforeSave
    }

    public func importCards(
        _ imported: [VocabularyCard],
        replacingCardIDs: Set<UUID>
    ) async throws -> CardMergeResult {
        try CardImportValidator.validate(imported)
        let context = ModelContext(retainedContainer)
        let existing = try context.fetch(FetchDescriptor<CardEntity>())
            .map(VocabularyCardMapper.toDomain)
        let importedByID = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        let existingIDs = Set(existing.map(\.id))
        let replacements = replacingCardIDs
            .intersection(importedByID.keys)
            .intersection(existingIDs)
        let replacementCardsByID = importedByID.filter { replacements.contains($0.key) }
        let stagedExisting = existing.map { replacementCardsByID[$0.id] ?? $0 }
        let additions = imported.filter { !replacements.contains($0.id) }
        try CardImportValidator.validate(additions, against: stagedExisting)
        let merged = CardMergeService.merge(existing: stagedExisting, imported: additions)
        let result = CardMergeResult(
            cards: merged.cards,
            addedCount: merged.addedCount,
            mergedCount: merged.mergedCount + replacements.count,
            affectedCardIDs: merged.affectedCardIDs.union(replacements)
        )
        try CardImportValidator.validate(result.cards)

        var tagsByName = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<TagEntity>()).map {
                ($0.normalizedName, $0)
            }
        )
        let cardsByID = Dictionary(uniqueKeysWithValues: try context.fetch(
            FetchDescriptor<CardEntity>()
        ).map { ($0.id, $0) })

        for card in result.cards {
            let resolvedTags = card.tags.map { tag in
                let displayName = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedName = TextNormalizer.searchKey(displayName)
                if let existing = tagsByName[normalizedName] {
                    return existing
                }
                let entity = TagEntity(
                    id: UUID(),
                    name: displayName,
                    normalizedName: normalizedName
                )
                context.insert(entity)
                tagsByName[normalizedName] = entity
                return entity
            }

            if let entity = cardsByID[card.id] {
                entity.russianMeanings.forEach(context.delete)
                entity.englishVariants.forEach(context.delete)
                VocabularyCardMapper.update(entity, from: card, tags: resolvedTags)
            } else {
                context.insert(VocabularyCardMapper.makeEntity(from: card, tags: resolvedTags))
            }
        }

        try beforeSave()
        try context.save()
        return result
    }
}
