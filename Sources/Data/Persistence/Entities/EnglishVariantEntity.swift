import Foundation
import SwiftData

@Model
final class EnglishVariantEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var ipa: String?
    var partOfSpeechRawValues: [String]
    var sortIndex: Int
    var card: CardEntity?

    @Relationship(deleteRule: .cascade, inverse: \UsageExampleEntity.variant)
    var usageExamples: [UsageExampleEntity]

    init(
        id: UUID,
        text: String,
        ipa: String?,
        partOfSpeechRawValues: [String],
        sortIndex: Int,
        usageExamples: [UsageExampleEntity] = []
    ) {
        self.id = id
        self.text = text
        self.ipa = ipa
        self.partOfSpeechRawValues = partOfSpeechRawValues
        self.sortIndex = sortIndex
        self.usageExamples = usageExamples
    }
}
