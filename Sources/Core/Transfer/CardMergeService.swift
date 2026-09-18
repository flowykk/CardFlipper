import Foundation

public struct CardMergeResult: Sendable {
    public let cards: [VocabularyCard]
    public let addedCount: Int
    public let mergedCount: Int
    public let affectedCardIDs: Set<UUID>

    public init(
        cards: [VocabularyCard],
        addedCount: Int,
        mergedCount: Int,
        affectedCardIDs: Set<UUID> = []
    ) {
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
        var affectedCardIDs: Set<UUID> = []

        for importedCard in imported {
            if let index = result.firstIndex(where: { cardsMatch($0, importedCard) }) {
                result[index] = merge(result[index], importedCard)
                affectedCardIDs.insert(result[index].id)
                merged += 1
            } else {
                let card = result.contains(where: { $0.id == importedCard.id })
                    ? importedCard.replacingID(with: UUID())
                    : importedCard
                result.append(card)
                affectedCardIDs.insert(card.id)
                added += 1
            }
        }
        return CardMergeResult(
            cards: result,
            addedCount: added,
            mergedCount: merged,
            affectedCardIDs: affectedCardIDs
        )
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

private extension VocabularyCard {
    func replacingID(with id: UUID) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: russianMeanings,
            englishVariants: englishVariants,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLearned: isLearned
        )
    }
}

public enum CardImportChangeKind: CaseIterable, Equatable, Sendable {
    case added
    case updated
    case unchanged
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
    public let replacingCardIDs: Set<UUID>

    public var cardsToSave: [VocabularyCard] {
        changes.filter { $0.kind != .unchanged }.map(\.card)
    }

    public var draftCards: [VocabularyCard] {
        let changesByID = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0.card) })
        let existingIDs = Set(originalCards.map(\.id))
        return originalCards.map { changesByID[$0.id] ?? $0 }
            + changes.filter { !existingIDs.contains($0.id) }.map(\.card)
    }

    public init(
        fileName: String,
        existing: [VocabularyCard],
        imported: [VocabularyCard],
        replacingCardIDs: Set<UUID> = []
    ) {
        self.fileName = fileName
        originalCards = existing
        let importedByID = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        let existingIDs = Set(existing.map(\.id))
        let replacements = replacingCardIDs
            .intersection(importedByID.keys)
            .intersection(existingIDs)
        let replacementCardsByID = importedByID.filter { replacements.contains($0.key) }
        let stagedExisting = existing.map { replacementCardsByID[$0.id] ?? $0 }
        let additions = imported.filter { !replacements.contains($0.id) }
        let merged = CardMergeService.merge(existing: stagedExisting, imported: additions)
        let affectedCardIDs = merged.affectedCardIDs.union(replacements)
        let originals = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        changes = merged.cards
            .filter { affectedCardIDs.contains($0.id) }
            .map { card in
                let before = originals[card.id]
                let kind: CardImportChangeKind
                if let before {
                    kind = before.hasSameImportContent(as: card) ? .unchanged : .updated
                } else {
                    kind = .added
                }
                return CardImportChange(card: card, before: before, kind: kind)
            }
        importedCards = changes.map(\.card)
        self.replacingCardIDs = Set(changes.compactMap { $0.before?.id })
    }

    public func replacingEditedCards(_ editedCards: [VocabularyCard]) -> CardImportPreview {
        return CardImportPreview(
            fileName: fileName,
            existing: originalCards,
            imported: editedCards.filter { card in
                changes.contains { $0.id == card.id }
            },
            replacingCardIDs: replacingCardIDs
        )
    }
}

private extension VocabularyCard {
    func hasSameImportContent(as other: VocabularyCard) -> Bool {
        russianMeanings == other.russianMeanings
            && englishVariants == other.englishVariants
            && tags == other.tags
            && isLearned == other.isLearned
    }
}
