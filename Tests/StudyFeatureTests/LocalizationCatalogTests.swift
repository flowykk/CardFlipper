import Core
import Foundation
import Testing

@Test func everyPartOfSpeechHasEnglishAndRussianCatalogValues() throws {
    let catalog = try loadLocalizationCatalog()

    for partOfSpeech in PartOfSpeech.allCases {
        let key = "partOfSpeech.\(partOfSpeech.rawValue)"

        for locale in ["en", "ru"] {
            let value = catalog[key]?[locale]

            #expect(value != nil, "Missing \(locale) localization for \(key)")
            #expect(value?.isEmpty == false, "Empty \(locale) localization for \(key)")
            #expect(value != key, "Unresolved \(locale) localization for \(key)")
        }
    }
}

@Test func resultExtraAttemptsCopyIsAccuratelyPluralizedInEnglishAndRussian() throws {
    let values = try loadPluralCatalogValues(key: "study.result.extraAttempts")

    #expect(values["en"] == [
        "one": "%lld extra attempt",
        "other": "%lld extra attempts",
    ])
    #expect(values["ru"] == [
        "one": "%lld дополнительная попытка",
        "few": "%lld дополнительные попытки",
        "many": "%lld дополнительных попыток",
        "other": "%lld дополнительной попытки",
    ])
}

@Test func usageExampleCountCopyIsAccuratelyPluralizedInEnglishAndRussian() throws {
    let values = try loadPluralCatalogValues(key: "study.examples.count")

    #expect(values["en"] == [
        "one": "%lld example",
        "other": "%lld examples",
    ])
    #expect(values["ru"] == [
        "one": "%lld пример",
        "few": "%lld примера",
        "many": "%lld примеров",
        "other": "%lld примера",
    ])
}

private func loadLocalizationCatalog() throws -> [String: [String: String]] {
    let strings = try loadCatalogStringsRoot()

    return strings.reduce(into: [:]) { result, entry in
        guard let definition = entry.value as? [String: Any],
              let localizations = definition["localizations"] as? [String: Any]
        else {
            return
        }

        result[entry.key] = localizations.reduce(into: [:]) { values, localization in
            guard let localizedDefinition = localization.value as? [String: Any],
                  let stringUnit = localizedDefinition["stringUnit"] as? [String: Any],
                  let value = stringUnit["value"] as? String
            else {
                return
            }

            values[localization.key] = value
        }
    }
}

private func loadPluralCatalogValues(key: String) throws -> [String: [String: String]] {
    let strings = try loadCatalogStringsRoot()
    let definition = try #require(strings[key] as? [String: Any])
    let localizations = try #require(definition["localizations"] as? [String: Any])

    return localizations.reduce(into: [:]) { result, localization in
        guard let localizedDefinition = localization.value as? [String: Any],
              let variations = localizedDefinition["variations"] as? [String: Any],
              let plurals = variations["plural"] as? [String: Any]
        else {
            return
        }

        result[localization.key] = plurals.reduce(into: [:]) { values, plural in
            guard let pluralDefinition = plural.value as? [String: Any],
                  let stringUnit = pluralDefinition["stringUnit"] as? [String: Any],
                  let value = stringUnit["value"] as? String
            else {
                return
            }

            values[plural.key] = value
        }
    }
}

private func loadCatalogStringsRoot() throws -> [String: Any] {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let catalogURL = repositoryRoot
        .appendingPathComponent("Resources/CardFlipperApp/Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try #require(root["strings"] as? [String: Any])
}
