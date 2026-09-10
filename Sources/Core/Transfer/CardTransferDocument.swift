import Foundation

public struct CardTransferDocument: Codable, Sendable {
    public let version: Int
    public let cards: [TransferCard]

    public init(cards: [VocabularyCard]) {
        version = 1
        self.cards = cards.map(TransferCard.init)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case cards
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        cards = try container.decode([TransferCard].self, forKey: .cards)
    }

    public func decodedCards() -> [VocabularyCard] {
        cards.map(\.card)
    }
}

public struct TransferCard: Codable, Sendable {
    public let id: UUID
    public let russianMeanings: [TransferRussianMeaning]
    public let englishVariants: [TransferEnglishVariant]
    public let tags: [TransferTag]
    public let createdAt: Date
    public let updatedAt: Date
    public let isLearned: Bool

    init(_ card: VocabularyCard) {
        id = card.id
        russianMeanings = card.russianMeanings.map(TransferRussianMeaning.init)
        englishVariants = card.englishVariants.map(TransferEnglishVariant.init)
        tags = card.tags.map(TransferTag.init)
        createdAt = card.createdAt
        updatedAt = card.updatedAt
        isLearned = card.isLearned
    }

    var card: VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: russianMeanings.map(\.meaning),
            englishVariants: englishVariants.map(\.variant),
            tags: tags.map(\.tag),
            createdAt: createdAt,
            updatedAt: updatedAt,
            isLearned: isLearned
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, russianMeanings, englishVariants, tags, createdAt, updatedAt, isLearned
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        russianMeanings = try container.decode([TransferRussianMeaning].self, forKey: .russianMeanings)
        englishVariants = try container.decode([TransferEnglishVariant].self, forKey: .englishVariants)
        tags = try container.decode([TransferTag].self, forKey: .tags)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isLearned = try container.decodeIfPresent(Bool.self, forKey: .isLearned) ?? false
    }
}

public struct TransferRussianMeaning: Codable, Sendable {
    public let id: UUID
    public let text: String
    init(_ value: RussianMeaning) { id = value.id; text = value.text }
    var meaning: RussianMeaning { RussianMeaning(id: id, text: text) }
}

public struct TransferTag: Codable, Sendable {
    public let id: UUID
    public let name: String
    init(_ value: Tag) { id = value.id; name = value.name }
    var tag: Tag { Tag(id: id, name: name) }
}

public struct TransferUsageExample: Codable, Sendable {
    public let id: UUID
    public let text: String
    public let partOfSpeechRawValue: String
    init(_ value: UsageExample) { id = value.id; text = value.text; partOfSpeechRawValue = value.partOfSpeech.rawValue }
    var example: UsageExample { UsageExample(id: id, text: text, partOfSpeech: PartOfSpeech(rawValue: partOfSpeechRawValue) ?? .other) }
}

public struct TransferEnglishVariant: Codable, Sendable {
    public let id: UUID
    public let text: String
    public let ipa: String?
    public let partsOfSpeechRawValues: [String]
    public let usageExamples: [TransferUsageExample]
    init(_ value: EnglishVariant) {
        id = value.id; text = value.text; ipa = value.ipa
        partsOfSpeechRawValues = value.partsOfSpeech.map(\.rawValue)
        usageExamples = value.usageExamples.map(TransferUsageExample.init)
    }
    var variant: EnglishVariant {
        EnglishVariant(
            id: id,
            text: text,
            ipa: ipa,
            partsOfSpeech: partsOfSpeechRawValues.compactMap(PartOfSpeech.init(rawValue:)),
            usageExamples: usageExamples.map(\.example)
        )
    }
}
