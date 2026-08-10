#if DEBUG
import Foundation
import SwiftData

public enum UITestVocabularySeed {
    public static let cardIDs: [UUID] = [1, 2, 3].map(seedID)

    @MainActor
    public static func insert(into container: ModelContainer) throws {
        let context = container.mainContext
        let tag = TagEntity(id: seedID(100), name: "Основы")
        context.insert(tag)

        let fixtures = [
            (1, "книга", "book", "bʊk", "noun", 300.0),
            (2, "кот", "cat", "kæt", "noun", 200.0),
            (3, "дом", "home", "həʊm", "noun", 100.0),
        ]

        for (id, russian, english, ipa, partOfSpeech, timestamp) in fixtures {
            let card = CardEntity(
                id: seedID(id),
                createdAt: Date(timeIntervalSince1970: timestamp),
                updatedAt: Date(timeIntervalSince1970: timestamp),
                russianMeanings: [
                    RussianMeaningEntity(id: seedID(1_000 + id), text: russian, sortIndex: 0),
                ],
                englishVariants: [
                    EnglishVariantEntity(
                        id: seedID(2_000 + id),
                        text: english,
                        ipa: ipa,
                        partOfSpeechRawValues: [partOfSpeech],
                        sortIndex: 0
                    ),
                ],
                tags: [tag]
            )
            context.insert(card)
        }

        try context.save()
    }

    private static func seedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
#endif
