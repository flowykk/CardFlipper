import Foundation
import SwiftData

@Model
final class TagEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    @Attribute(.unique) var normalizedName: String

    @Relationship(deleteRule: .nullify)
    var cards: [CardEntity]

    init(
        id: UUID,
        name: String,
        normalizedName: String,
        cards: [CardEntity] = []
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.cards = cards
    }
}
