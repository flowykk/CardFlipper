import Foundation
import SwiftData

@Model
final class RussianMeaningEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var sortIndex: Int
    var card: CardEntity?

    init(id: UUID, text: String, sortIndex: Int) {
        self.id = id
        self.text = text
        self.sortIndex = sortIndex
    }
}
