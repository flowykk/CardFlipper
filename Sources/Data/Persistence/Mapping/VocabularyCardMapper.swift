import Core

enum VocabularyCardMapper {
    static func toDomain(_ entity: CardEntity) -> VocabularyCard {
        VocabularyCard(
            id: entity.id,
            russianMeanings: entity.russianMeanings
                .sorted { $0.sortIndex < $1.sortIndex }
                .map { RussianMeaning(id: $0.id, text: $0.text) },
            englishVariants: entity.englishVariants
                .sorted { $0.sortIndex < $1.sortIndex }
                .map {
                    EnglishVariant(
                        id: $0.id,
                        text: $0.text,
                        ipa: $0.ipa,
                        partsOfSpeech: $0.partOfSpeechRawValues.map {
                            PartOfSpeech(rawValue: $0) ?? .other
                        }
                    )
                },
            tags: entity.tags
                .map { Tag(id: $0.id, name: $0.name) }
                .sorted { $0.name < $1.name },
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    static func makeEntity(
        from card: VocabularyCard,
        tags: [TagEntity]
    ) -> CardEntity {
        CardEntity(
            id: card.id,
            createdAt: card.createdAt,
            updatedAt: card.updatedAt,
            russianMeanings: makeRussianMeanings(from: card),
            englishVariants: makeEnglishVariants(from: card),
            tags: tags
        )
    }

    static func update(
        _ entity: CardEntity,
        from card: VocabularyCard,
        tags: [TagEntity]
    ) {
        entity.createdAt = card.createdAt
        entity.updatedAt = card.updatedAt
        entity.russianMeanings = makeRussianMeanings(from: card)
        entity.englishVariants = makeEnglishVariants(from: card)
        entity.tags = tags
    }

    private static func makeRussianMeanings(
        from card: VocabularyCard
    ) -> [RussianMeaningEntity] {
        card.russianMeanings.enumerated().map { sortIndex, meaning in
            RussianMeaningEntity(
                id: meaning.id,
                text: meaning.text,
                sortIndex: sortIndex
            )
        }
    }

    private static func makeEnglishVariants(
        from card: VocabularyCard
    ) -> [EnglishVariantEntity] {
        card.englishVariants.enumerated().map { sortIndex, variant in
            EnglishVariantEntity(
                id: variant.id,
                text: variant.text,
                ipa: variant.ipa,
                partOfSpeechRawValues: variant.partsOfSpeech.map(\.rawValue),
                sortIndex: sortIndex
            )
        }
    }
}
