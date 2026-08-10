import Foundation

public enum PartOfSpeech: String, CaseIterable, Equatable, Sendable {
    case noun
    case verb
    case adj
    case adv
    case pronoun
    case preposition
    case conjunction
    case interjection
    case determiner
    case numeral
    case auxiliary
    case modal
    case phrase
    case other

    public init(apiValue: String) {
        switch apiValue.lowercased() {
        case "adjective":
            self = .adj
        case "adverb":
            self = .adv
        case "exclamation":
            self = .interjection
        default:
            self = Self(rawValue: apiValue.lowercased()) ?? .other
        }
    }

    public var localizationKey: String {
        switch self {
        case .noun: "partOfSpeech.noun"
        case .verb: "partOfSpeech.verb"
        case .adj: "partOfSpeech.adj"
        case .adv: "partOfSpeech.adv"
        case .pronoun: "partOfSpeech.pronoun"
        case .preposition: "partOfSpeech.preposition"
        case .conjunction: "partOfSpeech.conjunction"
        case .interjection: "partOfSpeech.interjection"
        case .determiner: "partOfSpeech.determiner"
        case .numeral: "partOfSpeech.numeral"
        case .auxiliary: "partOfSpeech.auxiliary"
        case .modal: "partOfSpeech.modal"
        case .phrase: "partOfSpeech.phrase"
        case .other: "partOfSpeech.other"
        }
    }

    public func localizedName(bundle: Bundle = .main) -> String {
        bundle.localizedString(
            forKey: localizationKey,
            value: localizationKey,
            table: nil
        )
    }

    public func localizedName(
        bundle: Bundle = .main,
        locale: Locale
    ) -> String {
        let localizedBundle = localeBundle(
            for: locale,
            in: bundle
        )
        return localizedBundle.localizedString(
            forKey: localizationKey,
            value: localizationKey,
            table: nil
        )
    }

    private func localeBundle(for locale: Locale, in bundle: Bundle) -> Bundle {
        let identifiers = locale.identifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .reduce(into: [locale.identifier]) { candidates, component in
                let identifier = String(component)
                if !candidates.contains(identifier) {
                    candidates.append(identifier)
                }
            }

        for identifier in identifiers {
            guard let path = bundle.path(
                forResource: identifier,
                ofType: "lproj"
            ), let localizedBundle = Bundle(path: path) else {
                continue
            }
            return localizedBundle
        }
        return bundle
    }
}
