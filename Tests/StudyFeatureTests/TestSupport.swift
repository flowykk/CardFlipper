import Core
import Foundation
@testable import StudyFeature

struct IdentityShuffler: CardShuffler {
    func shuffle(_ cards: [VocabularyCard]) -> [VocabularyCard] { cards }
}

struct ReversingShuffler: CardShuffler {
    func shuffle(_ cards: [VocabularyCard]) -> [VocabularyCard] { cards.reversed() }
}

final class CountingShuffler: CardShuffler, @unchecked Sendable {
    private(set) var invocationCount = 0

    func shuffle(_ cards: [VocabularyCard]) -> [VocabularyCard] {
        invocationCount += 1
        return cards.reversed()
    }
}

@MainActor
final class SpeechServiceSpy: SpeechService {
    private(set) var spokenTexts: [String] = []

    func speak(_ text: String) {
        spokenTexts.append(text)
    }
}

@MainActor
final class StudyFeedbackSpy: StudyFeedback {
    private(set) var events: [StudyFeedbackEvent] = []

    func perform(_ event: StudyFeedbackEvent) {
        events.append(event)
    }
}

extension UUID {
    static func fixture(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

extension Tag {
    static let work = Tag(id: .fixture(100), name: "Work")
    static let exam = Tag(id: .fixture(101), name: "Exam")
}

extension VocabularyCard {
    static func fixture(
        id: Int,
        russian: String = "слово",
        english: String = "word",
        ipa: String? = "/wɜːd/",
        partsOfSpeech: [PartOfSpeech] = [.noun],
        tags: [Tag] = []
    ) -> VocabularyCard {
        VocabularyCard(
            id: .fixture(id),
            russianMeanings: [RussianMeaning(id: .fixture(id + 1_000), text: russian)],
            englishVariants: [
                EnglishVariant(
                    id: .fixture(id + 2_000),
                    text: english,
                    ipa: ipa,
                    partsOfSpeech: partsOfSpeech
                )
            ],
            tags: tags,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id))
        )
    }
}

extension StudyConfiguration {
    static let singleCard = StudyConfiguration(
        direction: .russianToEnglish,
        selectedTagIDs: [],
        cards: [.fixture(id: 1, russian: "слово", english: "word")]
    )

    static let fixture = StudyConfiguration(
        direction: .russianToEnglish,
        selectedTagIDs: [Tag.work.id],
        cards: [
            .fixture(id: 1, russian: "первый", english: "first", tags: [.work]),
            .fixture(id: 2, russian: "второй", english: "second", tags: [.work]),
        ]
    )
}
