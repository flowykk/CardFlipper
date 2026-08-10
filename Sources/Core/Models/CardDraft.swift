import Foundation

public struct EnglishVariantDraft: Equatable, Sendable {
    public var text: String
    public var ipa: String?
    public var partsOfSpeech: [PartOfSpeech]

    public init(
        text: String,
        ipa: String? = nil,
        partsOfSpeech: [PartOfSpeech] = []
    ) {
        self.text = text
        self.ipa = ipa
        self.partsOfSpeech = partsOfSpeech
    }
}

public struct CardDraft: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case missingRussianMeaning
        case missingEnglishVariant
    }

    public enum ChildIdentityError: Error, Equatable, Sendable {
        case russianMeaningCountMismatch
        case englishVariantCountMismatch
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

        return errors
    }

    public func makeCard(id: UUID, now: Date) throws -> VocabularyCard {
        try makeCard(
            id: id,
            russianMeaningIDs: russianMeanings.map { _ in UUID() },
            englishVariantIDs: englishVariants.map { _ in UUID() },
            now: now
        )
    }

    public func makeCard(
        id: UUID,
        russianMeaningIDs: [UUID],
        englishVariantIDs: [UUID],
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

        return VocabularyCard(
            id: id,
            russianMeanings: zip(russianMeaningIDs, russianMeanings).compactMap { id, text in
                let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedText.isEmpty else { return nil }
                return RussianMeaning(id: id, text: normalizedText)
            },
            englishVariants: zip(englishVariantIDs, englishVariants).compactMap { id, variant in
                guard let normalizedVariant = normalize(variant) else { return nil }
                return EnglishVariant(
                    id: id,
                    text: normalizedVariant.text,
                    ipa: normalizedVariant.ipa,
                    partsOfSpeech: normalizedVariant.partsOfSpeech
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
            partsOfSpeech: variant.partsOfSpeech
        )
    }
}
