import Foundation
import SwiftData

@Model
final class UsageExampleEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var partOfSpeechRawValue: String
    var sortIndex: Int
    var variant: EnglishVariantEntity?

    init(
        id: UUID,
        text: String,
        partOfSpeechRawValue: String,
        sortIndex: Int
    ) {
        self.id = id
        self.text = text
        self.partOfSpeechRawValue = partOfSpeechRawValue
        self.sortIndex = sortIndex
    }
}
