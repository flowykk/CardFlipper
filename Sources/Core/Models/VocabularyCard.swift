import Foundation

public struct VocabularyCard: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let russianMeanings: [RussianMeaning]
    public let englishVariants: [EnglishVariant]
    public let tags: [Tag]
    public let createdAt: Date
    public let updatedAt: Date
    public let isLearned: Bool

    public init(
        id: UUID,
        russianMeanings: [RussianMeaning],
        englishVariants: [EnglishVariant],
        tags: [Tag],
        createdAt: Date,
        updatedAt: Date,
        isLearned: Bool = false
    ) {
        self.id = id
        self.russianMeanings = russianMeanings
        self.englishVariants = englishVariants
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isLearned = isLearned
    }

    public var searchableValues: [String] {
        russianMeanings.map(\.text)
            + englishVariants.map(\.text)
            + englishVariants.flatMap { $0.usageExamples.map(\.text) }
    }

    public func updating(
        tags: [Tag]? = nil,
        isLearned: Bool? = nil,
        updatedAt: Date? = nil
    ) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: russianMeanings,
            englishVariants: englishVariants,
            tags: tags ?? self.tags,
            createdAt: createdAt,
            updatedAt: updatedAt ?? self.updatedAt,
            isLearned: isLearned ?? self.isLearned
        )
    }
}

public struct RussianMeaning: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String

    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }
}

public struct EnglishVariant: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let ipa: String?
    public let partsOfSpeech: [PartOfSpeech]
    public let usageExamples: [UsageExample]

    public init(
        id: UUID,
        text: String,
        ipa: String?,
        partsOfSpeech: [PartOfSpeech],
        usageExamples: [UsageExample] = []
    ) {
        self.id = id
        self.text = text
        self.ipa = ipa
        self.partsOfSpeech = partsOfSpeech
        self.usageExamples = usageExamples
    }
}

public struct UsageExample: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let partOfSpeech: PartOfSpeech

    public init(
        id: UUID,
        text: String,
        partOfSpeech: PartOfSpeech
    ) {
        self.id = id
        self.text = text
        self.partOfSpeech = partOfSpeech
    }
}
