import SwiftData

enum CardFlipperSchema {
    static let schema = Schema([
        CardEntity.self,
        RussianMeaningEntity.self,
        EnglishVariantEntity.self,
        TagEntity.self,
    ])
}
