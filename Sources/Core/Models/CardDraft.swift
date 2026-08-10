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
        if let error = validationErrors.first {
            throw error
        }

        return VocabularyCard(
            id: id,
            russianMeanings: normalizedRussianMeanings.map {
                RussianMeaning(id: UUID(), text: $0)
            },
            englishVariants: normalizedEnglishVariants.map {
                EnglishVariant(
                    id: UUID(),
                    text: $0.text,
                    ipa: $0.ipa,
                    partsOfSpeech: $0.partsOfSpeech
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
        englishVariants.compactMap { variant in
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
}
