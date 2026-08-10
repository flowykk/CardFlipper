import Foundation

public struct UsageExampleDraft: Equatable, Sendable {
    public var text: String
    public var partOfSpeech: PartOfSpeech?

    public init(
        text: String,
        partOfSpeech: PartOfSpeech? = nil
    ) {
        self.text = text
        self.partOfSpeech = partOfSpeech
    }
}

public struct EnglishVariantDraft: Equatable, Sendable {
    public var text: String
    public var ipa: String?
    public var partsOfSpeech: [PartOfSpeech]
    public var usageExamples: [UsageExampleDraft]

    public init(
        text: String,
        ipa: String? = nil,
        partsOfSpeech: [PartOfSpeech] = [],
        usageExamples: [UsageExampleDraft] = []
    ) {
        self.text = text
        self.ipa = ipa
        self.partsOfSpeech = partsOfSpeech
        self.usageExamples = usageExamples
    }
}

public struct CardDraft: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case missingRussianMeaning
        case missingEnglishVariant
        case missingUsageExamplePartOfSpeech
    }

    public enum ChildIdentityError: Error, Equatable, Sendable {
        case russianMeaningCountMismatch
        case englishVariantCountMismatch
        case usageExampleVariantCountMismatch
        case usageExampleCountMismatch
    }

    public var russianMeanings: [String]
    public var englishVariants: [EnglishVariantDraft]
    public var tagIDs: [UUID]

    public init(
        russianMeanings: [String],
        englishVariants: [EnglishVariantDraft],
        tagIDs: [UUID]
    ) {
        self.russianMeanings = russianMeanings
        self.englishVariants = englishVariants
        self.tagIDs = tagIDs
    }

    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []

        if normalizedRussianMeanings.isEmpty {
            errors.append(.missingRussianMeaning)
        }
        if normalizedEnglishVariants.isEmpty {
            errors.append(.missingEnglishVariant)
        }
        if englishVariants.contains(where: hasInvalidUsageExample) {
            errors.append(.missingUsageExamplePartOfSpeech)
        }

        return errors
    }

    public func makeCard(id: UUID, now: Date) throws -> VocabularyCard {
        try makeCard(
            id: id,
            russianMeaningIDs: russianMeanings.map { _ in UUID() },
            englishVariantIDs: englishVariants.map { _ in UUID() },
            usageExampleIDsByVariant: englishVariants.map { variant in
                variant.usageExamples.map { _ in UUID() }
            },
            now: now
        )
    }

    public func makeCard(
        id: UUID,
        russianMeaningIDs: [UUID],
        englishVariantIDs: [UUID],
        now: Date
    ) throws -> VocabularyCard {
        try makeCard(
            id: id,
            russianMeaningIDs: russianMeaningIDs,
            englishVariantIDs: englishVariantIDs,
            usageExampleIDsByVariant: englishVariants.map { variant in
                variant.usageExamples.map { _ in UUID() }
            },
            now: now
        )
    }

    public func makeCard(
        id: UUID,
        russianMeaningIDs: [UUID],
        englishVariantIDs: [UUID],
        usageExampleIDsByVariant: [[UUID]],
        now: Date
    ) throws -> VocabularyCard {
        if let error = validationErrors.first {
            throw error
        }
        guard russianMeaningIDs.count == russianMeanings.count else {
            throw ChildIdentityError.russianMeaningCountMismatch
        }
        guard englishVariantIDs.count == englishVariants.count else {
            throw ChildIdentityError.englishVariantCountMismatch
        }
        guard usageExampleIDsByVariant.count == englishVariants.count else {
            throw ChildIdentityError.usageExampleVariantCountMismatch
        }
        guard zip(usageExampleIDsByVariant, englishVariants).allSatisfy({ ids, variant in
            ids.count == variant.usageExamples.count
        }) else {
            throw ChildIdentityError.usageExampleCountMismatch
        }

        return VocabularyCard(
            id: id,
            russianMeanings: zip(russianMeaningIDs, russianMeanings).compactMap { id, text in
                let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedText.isEmpty else { return nil }
                return RussianMeaning(id: id, text: normalizedText)
            },
            englishVariants: zip(
                zip(englishVariantIDs, englishVariants),
                usageExampleIDsByVariant
            ).compactMap { pair, usageExampleIDs in
                let (id, variant) = pair
                guard let normalizedVariant = normalize(variant) else { return nil }
                return EnglishVariant(
                    id: id,
                    text: normalizedVariant.text,
                    ipa: normalizedVariant.ipa,
                    partsOfSpeech: normalizedVariant.partsOfSpeech,
                    usageExamples: zip(usageExampleIDs, variant.usageExamples).compactMap {
                        exampleID, example in
                        guard let normalizedExample = normalize(example),
                              let partOfSpeech = normalizedExample.partOfSpeech else {
                            return nil
                        }
                        return UsageExample(
                            id: exampleID,
                            text: normalizedExample.text,
                            partOfSpeech: partOfSpeech
                        )
                    }
                )
            },
            tags: [],
            createdAt: now,
            updatedAt: now
        )
    }

    private var normalizedRussianMeanings: [String] {
        russianMeanings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var normalizedEnglishVariants: [EnglishVariantDraft] {
        englishVariants.compactMap(normalize)
    }

    private func normalize(_ variant: EnglishVariantDraft) -> EnglishVariantDraft? {
        let text = variant.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let trimmedIPA = variant.ipa?.trimmingCharacters(in: .whitespacesAndNewlines)
        return EnglishVariantDraft(
            text: text,
            ipa: trimmedIPA?.isEmpty == true ? nil : trimmedIPA,
            partsOfSpeech: variant.partsOfSpeech,
            usageExamples: variant.usageExamples.compactMap(normalize)
        )
    }

    private func normalize(_ example: UsageExampleDraft) -> UsageExampleDraft? {
        let text = example.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return UsageExampleDraft(text: text, partOfSpeech: example.partOfSpeech)
    }

    private func hasInvalidUsageExample(_ variant: EnglishVariantDraft) -> Bool {
        variant.usageExamples.contains { example in
            guard normalize(example) != nil else { return false }
            guard let partOfSpeech = example.partOfSpeech else { return true }
            return !variant.partsOfSpeech.contains(partOfSpeech)
        }
    }
}
