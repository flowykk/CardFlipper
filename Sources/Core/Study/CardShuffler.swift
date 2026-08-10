public protocol CardShuffler: Sendable {
    func shuffle(_ cards: [VocabularyCard]) -> [VocabularyCard]
}

public struct SystemCardShuffler: CardShuffler {
    public init() {}

    public func shuffle(_ cards: [VocabularyCard]) -> [VocabularyCard] {
        cards.shuffled()
    }
}
