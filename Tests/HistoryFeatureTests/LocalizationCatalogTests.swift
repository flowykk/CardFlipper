@testable import HistoryFeature
import Foundation
import Testing

@Test func historyDurationUsesEnglishAndRussianPluralForms() {
    let examples: [(String, Int, String)] = [
        ("en", 0, "0 seconds"), ("en", 1, "1 second"), ("en", 2, "2 seconds"),
        ("ru", 0, "0 секунд"), ("ru", 1, "1 секунда"), ("ru", 2, "2 секунды"),
        ("ru", 5, "5 секунд"), ("ru", 11, "11 секунд"), ("ru", 21, "21 секунда"),
        ("ru", 61, "61 секунда"),
    ]
    for (language, seconds, expected) in examples {
        let actual = String(
            format: HistoryLocalization.string("history.duration.format", language: language),
            locale: Locale(identifier: language),
            arguments: [seconds]
        )
        #expect(actual == expected)
    }
}

@Test func historyCatalogResolvesEverySupportedKeyInEnglishAndRussian() {
    let keys = [
        "history.title",
        "history.empty.title",
        "history.empty.message",
        "history.failure.title",
        "history.failure.message",
        "history.retry",
        "history.loading",
        "history.resume.section",
        "history.sessions.section",
        "history.detail.title",
        "history.mode.label",
        "history.mode.flashcards",
        "history.mode.writing",
        "history.direction.label",
        "history.direction.russianToEnglish",
        "history.direction.englishToRussian",
        "history.progress.label",
        "history.progress.format",
        "history.recall.label",
        "history.recall.format",
        "history.startedAt.label",
        "history.completedAt.label",
        "history.duration.label",
        "history.duration.format",
        "history.tags.label",
        "history.allCards",
        "history.difficultCards.label",
        "history.encountered.label",
        "history.repeated.label",
        "history.forgotten.label",
        "history.assessments.label",
        "history.continue",
        "history.lastActivity.format",
    ]

    for language in ["en", "ru"] {
        for key in keys {
            let value = HistoryLocalization.string(key, language: language)
            #expect(!value.isEmpty, "Missing \(language) localization for \(key)")
            #expect(value != key, "Unresolved \(language) localization for \(key)")
        }
    }
}
