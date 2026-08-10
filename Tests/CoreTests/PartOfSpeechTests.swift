import Testing
@testable import Core

@Test func fixedVocabularyUsesRequiredRawValues() {
    #expect(PartOfSpeech.allCases.map(\.rawValue) == [
        "noun",
        "verb",
        "adj",
        "adv",
        "pronoun",
        "preposition",
        "conjunction",
        "interjection",
        "determiner",
        "numeral",
        "auxiliary",
        "modal",
        "phrase",
        "other",
    ])
}

@Test func apiAliasesMapToFixedVocabulary() {
    #expect(PartOfSpeech(apiValue: "adjective") == .adj)
    #expect(PartOfSpeech(apiValue: "adverb") == .adv)
    #expect(PartOfSpeech(apiValue: "exclamation") == .interjection)
}

@Test func unknownAPIValuesFallBackToOther() {
    #expect(PartOfSpeech(apiValue: "unrecognized") == .other)
}
