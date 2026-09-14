import Foundation

public struct CardMergeResult: Sendable {
    public let cards: [VocabularyCard]
    public let addedCount: Int
    public let mergedCount: Int
    public let affectedCardIDs: Set<UUID>

    public init(cards: [VocabularyCard], addedCount: Int, mergedCount: Int, affectedCardIDs: Set<UUID> = []) {
        self.cards = cards
        self.addedCount = addedCount
        self.mergedCount = mergedCount
        self.affectedCardIDs = affectedCardIDs
    }
}

public enum CardMergeService {
    public static func merge(
        existing: [VocabularyCard],
        imported: [VocabularyCard]
    ) -> CardMergeResult {
        var result = existing
        var added = 0
        var merged = 0
        var affectedIDs: Set<UUID> = []

        for importedCard in imported {
            if let index = result.firstIndex(where: { cardsMatch($0, importedCard) }) {
                result[index] = merge(result[index], importedCard)
                affectedIDs.insert(result[index].id)
                merged += 1
            } else {
                // An unrelated imported card must not overwrite a card that shares its ID.
                let card = result.contains(where: { $0.id == importedCard.id })
                    ? VocabularyCard(
                        id: UUID(), russianMeanings: importedCard.russianMeanings,
                        englishVariants: importedCard.englishVariants, tags: importedCard.tags,
                        createdAt: importedCard.createdAt, updatedAt: importedCard.updatedAt,
                        isLearned: importedCard.isLearned
                    )
                    : importedCard
                result.append(card)
                affectedIDs.insert(card.id)
                added += 1
            }
        }
        return CardMergeResult(cards: result, addedCount: added, mergedCount: merged, affectedCardIDs: affectedIDs)
    }

    private static func cardsMatch(_ lhs: VocabularyCard, _ rhs: VocabularyCard) -> Bool {
        let left = Set(lhs.russianMeanings.map { TextNormalizer.searchKey($0.text) })
        let right = Set(rhs.russianMeanings.map { TextNormalizer.searchKey($0.text) })
        return !left.isDisjoint(with: right)
    }

    private static func merge(_ existing: VocabularyCard, _ imported: VocabularyCard) -> VocabularyCard {
        VocabularyCard(
            id: existing.id,
            russianMeanings: uniqueMeanings(existing.russianMeanings + imported.russianMeanings),
            englishVariants: uniqueVariants(existing.englishVariants + imported.englishVariants),
            tags: uniqueTags(existing.tags + imported.tags),
            createdAt: min(existing.createdAt, imported.createdAt),
            updatedAt: max(existing.updatedAt, imported.updatedAt),
            isLearned: imported.updatedAt > existing.updatedAt
                ? imported.isLearned
                : existing.isLearned
        )
    }

    private static func uniqueMeanings(_ values: [RussianMeaning]) -> [RussianMeaning] {
        unique(values) { TextNormalizer.searchKey($0.text) }
    }

    private static func uniqueVariants(_ values: [EnglishVariant]) -> [EnglishVariant] {
        var seen = Set<String>()
        return values.compactMap { variant in
            let key = TextNormalizer.searchKey(variant.text)
            guard seen.insert(key).inserted else { return nil }
            return variant
        }
    }

    private static func uniqueTags(_ values: [Tag]) -> [Tag] {
        unique(values) { TextNormalizer.searchKey($0.name) }
    }

    private static func unique<T>(_ values: [T], key: (T) -> String) -> [T] {
        var seen = Set<String>()
        return values.filter { seen.insert(key($0)).inserted }
    }
}

public enum CardImportChangeKind: CaseIterable, Sendable {
    case added, updated, unchanged
}

public struct CardImportChange: Identifiable, Sendable {
    public var id: UUID { card.id }
    public let card: VocabularyCard
    public let before: VocabularyCard?
    public let kind: CardImportChangeKind
}

public struct CardImportPreview: Identifiable, Sendable {
    public let id = UUID()
    public let fileName: String
    public let originalCards: [VocabularyCard]
    public let importedCards: [VocabularyCard]
    public let changes: [CardImportChange]

    public var cardsToSave: [VocabularyCard] {
        changes.filter { $0.kind != .unchanged }.map(\.card)
    }

    public init(fileName: String, existing: [VocabularyCard], imported: [VocabularyCard]) {
        self.fileName = fileName
        originalCards = existing
        importedCards = imported
        let result = CardMergeService.merge(existing: existing, imported: imported)
        let originals = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        changes = result.cards.filter { result.affectedCardIDs.contains($0.id) }.map { card in
            let before = originals[card.id]
            let kind: CardImportChangeKind
            if let before {
                let sameContent = before.russianMeanings == card.russianMeanings
                    && before.englishVariants == card.englishVariants
                    && before.tags == card.tags
                    && before.isLearned == card.isLearned
                kind = sameContent ? .unchanged : .updated
            } else {
                kind = .added
            }
            return CardImportChange(card: card, before: before, kind: kind)
        }
    }
}
