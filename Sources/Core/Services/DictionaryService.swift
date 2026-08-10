public struct DictionarySuggestion: Equatable, Sendable {
    public let ipa: String?
    public let partOfSpeech: PartOfSpeech?

    public init(ipa: String?, partOfSpeech: PartOfSpeech?) {
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
    }
}

public enum DictionaryServiceError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case server(Int)
}

public protocol DictionaryService: Sendable {
    func suggestion(for text: String) async throws -> DictionarySuggestion?
}
