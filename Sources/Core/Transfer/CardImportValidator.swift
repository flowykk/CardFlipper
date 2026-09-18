import Foundation

public enum CardImportValidationError: Error, Equatable, Sendable {
    case emptyRussianMeanings(cardID: UUID)
    case emptyEnglishVariants(cardID: UUID)
    case blankRussianMeaning(cardID: UUID)
    case blankEnglishVariant(cardID: UUID)
    case blankUsageExample(cardID: UUID)
    case blankTagName(cardID: UUID)
    case invalidUsageExamplePartOfSpeech(cardID: UUID)
    case duplicateTagName(cardID: UUID)
    case duplicateCardID(UUID)
    case duplicateRussianMeaningID(UUID)
    case duplicateEnglishVariantID(UUID)
    case duplicateUsageExampleID(UUID)
    case duplicateTagID(UUID)
    case conflictingTagIdentity(UUID)
}

public enum CardImportValidator {
    public static func validate(_ cards: [VocabularyCard]) throws {
        try rejectDuplicateIDs(in: cards.map(\.id), error: CardImportValidationError.duplicateCardID)

        var russianMeaningIDs: [UUID] = []
        var englishVariantIDs: [UUID] = []
        var usageExampleIDs: [UUID] = []
        var tagNamesByID: [UUID: String] = [:]

        for card in cards {
            guard !card.russianMeanings.isEmpty else {
                throw CardImportValidationError.emptyRussianMeanings(cardID: card.id)
            }
            guard !card.englishVariants.isEmpty else {
                throw CardImportValidationError.emptyEnglishVariants(cardID: card.id)
            }
            guard card.russianMeanings.allSatisfy({ !TextNormalizer.searchKey($0.text).isEmpty }) else {
                throw CardImportValidationError.blankRussianMeaning(cardID: card.id)
            }
            guard card.englishVariants.allSatisfy({ !TextNormalizer.searchKey($0.text).isEmpty }) else {
                throw CardImportValidationError.blankEnglishVariant(cardID: card.id)
            }
            guard card.englishVariants.flatMap(\.usageExamples).allSatisfy({
                !TextNormalizer.searchKey($0.text).isEmpty
            }) else {
                throw CardImportValidationError.blankUsageExample(cardID: card.id)
            }
            guard card.tags.allSatisfy({ !TextNormalizer.searchKey($0.name).isEmpty }) else {
                throw CardImportValidationError.blankTagName(cardID: card.id)
            }
            guard card.englishVariants.allSatisfy({ variant in
                variant.usageExamples.allSatisfy { variant.partsOfSpeech.contains($0.partOfSpeech) }
            }) else {
                throw CardImportValidationError.invalidUsageExamplePartOfSpeech(cardID: card.id)
            }
            try rejectDuplicateIDs(
                in: card.tags.map(\.id),
                error: CardImportValidationError.duplicateTagID
            )
            var normalizedTagNames = Set<String>()
            guard card.tags.allSatisfy({
                normalizedTagNames.insert(TextNormalizer.searchKey($0.name)).inserted
            }) else {
                throw CardImportValidationError.duplicateTagName(cardID: card.id)
            }
            for tag in card.tags {
                let normalizedName = TextNormalizer.searchKey(tag.name)
                if let existingName = tagNamesByID[tag.id], existingName != normalizedName {
                    throw CardImportValidationError.conflictingTagIdentity(tag.id)
                }
                tagNamesByID[tag.id] = normalizedName
            }

            russianMeaningIDs.append(contentsOf: card.russianMeanings.map(\.id))
            englishVariantIDs.append(contentsOf: card.englishVariants.map(\.id))
            usageExampleIDs.append(contentsOf: card.englishVariants.flatMap { $0.usageExamples.map(\.id) })
        }

        try rejectDuplicateIDs(
            in: russianMeaningIDs,
            error: CardImportValidationError.duplicateRussianMeaningID
        )
        try rejectDuplicateIDs(
            in: englishVariantIDs,
            error: CardImportValidationError.duplicateEnglishVariantID
        )
        try rejectDuplicateIDs(
            in: usageExampleIDs,
            error: CardImportValidationError.duplicateUsageExampleID
        )
    }

    public static func validate(
        _ imported: [VocabularyCard],
        against existing: [VocabularyCard],
        replacingCardIDs: Set<UUID> = []
    ) throws {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for card in imported {
            guard let existingCard = existingByID[card.id] else { continue }
            guard !replacingCardIDs.contains(card.id) else { continue }
            let existingMeanings = Set(
                existingCard.russianMeanings.map { TextNormalizer.searchKey($0.text) }
            )
            let importedMeanings = Set(
                card.russianMeanings.map { TextNormalizer.searchKey($0.text) }
            )
            guard !existingMeanings.isDisjoint(with: importedMeanings) else {
                throw CardImportValidationError.duplicateCardID(card.id)
            }
        }
    }

    private static func rejectDuplicateIDs(
        in ids: [UUID],
        error: (UUID) -> CardImportValidationError
    ) throws {
        var seen = Set<UUID>()
        if let duplicate = ids.first(where: { !seen.insert($0).inserted }) {
            throw error(duplicate)
        }
    }
}
