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
}
