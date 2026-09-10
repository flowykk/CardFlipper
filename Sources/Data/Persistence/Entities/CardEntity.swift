import Foundation
import SwiftData

@Model
final class CardEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isLearned: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \RussianMeaningEntity.card)
    var russianMeanings: [RussianMeaningEntity]

    @Relationship(deleteRule: .cascade, inverse: \EnglishVariantEntity.card)
    var englishVariants: [EnglishVariantEntity]

    @Relationship(deleteRule: .nullify, inverse: \TagEntity.cards)
    var tags: [TagEntity]

    init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        russianMeanings: [RussianMeaningEntity],
        englishVariants: [EnglishVariantEntity],
        tags: [TagEntity],
        isLearned: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isLearned = isLearned
        self.russianMeanings = russianMeanings
        self.englishVariants = englishVariants
        self.tags = tags
    }
}
