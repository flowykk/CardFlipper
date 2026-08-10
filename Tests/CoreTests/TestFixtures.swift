import Foundation
@testable import Core

enum TestFixtures {
    static let cardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let russianMeaningID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let englishVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let tagID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let date = Date(timeIntervalSince1970: 1)
}

extension VocabularyCard {
    static func fixture(
        id: UUID = TestFixtures.cardID,
        russian: String = "слово",
        english: String = "word",
        tag: Tag? = nil
    ) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: [RussianMeaning(id: TestFixtures.russianMeaningID, text: russian)],
            englishVariants: [EnglishVariant(id: TestFixtures.englishVariantID, text: english, ipa: nil, partsOfSpeech: [])],
            tags: tag.map { [$0] } ?? [],
            createdAt: TestFixtures.date,
            updatedAt: TestFixtures.date
        )
    }
}
