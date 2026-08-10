import Core
import Foundation

struct DictionaryEntryDTO: Decodable {
    let phonetic: String?
    let phonetics: [PhoneticDTO]
    let meanings: [MeaningDTO]

    var suggestion: DictionarySuggestion {
        DictionarySuggestion(
            ipa: firstNonEmptyIPA,
            partOfSpeech: firstPartOfSpeech
        )
    }

    private var firstNonEmptyIPA: String? {
        ([phonetic] + phonetics.map(\.text))
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private var firstPartOfSpeech: PartOfSpeech? {
        meanings
            .lazy
            .compactMap { $0.partOfSpeech?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            .map(PartOfSpeech.init(apiValue:))
    }
}

struct PhoneticDTO: Decodable {
    let text: String?
}

struct MeaningDTO: Decodable {
    let partOfSpeech: String?
}
