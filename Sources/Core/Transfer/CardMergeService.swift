import Foundation

public struct CardMergeResult: Sendable {
    public let cards: [VocabularyCard]
    public let addedCount: Int
    public let mergedCount: Int

    public init(cards: [VocabularyCard], addedCount: Int, mergedCount: Int) {
        self.cards = cards
        self.addedCount = addedCount
        self.mergedCount = mergedCount
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

        for importedCard in imported {
            if let index = result.firstIndex(where: { cardsMatch($0, importedCard) }) {
                result[index] = merge(result[index], importedCard)
                merged += 1
            } else {
                result.append(importedCard)
                added += 1
            }
        }
        return CardMergeResult(cards: result, addedCount: added, mergedCount: merged)
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
