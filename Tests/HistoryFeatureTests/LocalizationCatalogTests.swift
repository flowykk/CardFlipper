@testable import HistoryFeature
import Testing

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
