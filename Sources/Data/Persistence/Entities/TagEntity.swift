import Foundation
import SwiftData

@Model
final class TagEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String

    @Relationship(deleteRule: .nullify)
    var cards: [CardEntity]

    init(id: UUID, name: String, cards: [CardEntity] = []) {
        self.id = id
        self.name = name
        self.cards = cards
    }
}
