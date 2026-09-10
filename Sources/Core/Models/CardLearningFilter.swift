public enum CardLearningFilter: CaseIterable, Equatable, Hashable, Sendable {
    case all
    case learned
    case unlearned

    public func matches(_ card: VocabularyCard) -> Bool {
        switch self {
        case .all:
            true
        case .learned:
            card.isLearned
        case .unlearned:
            !card.isLearned
        }
    }
}
