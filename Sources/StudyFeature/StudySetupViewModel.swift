import Core
import Foundation
import Observation

public struct StudyConfiguration: Equatable, Sendable {
    public let direction: StudyDirection
    public let selectedTagIDs: Set<UUID>
    public let cards: [VocabularyCard]

    public init(
        direction: StudyDirection,
        selectedTagIDs: Set<UUID>,
        cards: [VocabularyCard]
    ) {
        self.direction = direction
        self.selectedTagIDs = selectedTagIDs
        self.cards = cards
    }
}

@MainActor
@Observable
public final class StudySetupViewModel {
    public private(set) var direction: StudyDirection?
    public private(set) var selectedTagIDs: Set<UUID>
    public let cards: [VocabularyCard]
    public let tags: [Tag]

    public init(cards: [VocabularyCard], tags: [Tag]) {
        self.cards = cards
        self.tags = tags
        direction = .englishToRussian
        selectedTagIDs = []
    }

    public var matchingCards: [VocabularyCard] {
        guard !selectedTagIDs.isEmpty else { return cards }

        return cards.filter { card in
            !selectedTagIDs.isDisjoint(with: card.tags.map(\.id))
        }
    }

    public var canStart: Bool {
        direction != nil && !matchingCards.isEmpty
    }

    public var configuration: StudyConfiguration? {
        guard let direction, !matchingCards.isEmpty else { return nil }

        return StudyConfiguration(
            direction: direction,
            selectedTagIDs: selectedTagIDs,
            cards: matchingCards
        )
    }

    public func chooseDirection(_ direction: StudyDirection) {
        self.direction = direction
    }

    public func toggleTag(_ id: UUID) {
        guard tags.contains(where: { $0.id == id }) else { return }

        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }
}
