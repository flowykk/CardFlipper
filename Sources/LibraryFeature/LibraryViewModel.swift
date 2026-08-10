import Core
import Foundation
import Observation

public enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}

public enum LibraryDeletionFailure: Equatable, Sendable {
    case card
    case tag
}

@MainActor
@Observable
public final class LibraryViewModel {
    public private(set) var cards: [VocabularyCard] = []
    public private(set) var tags: [Tag] = []
    public var searchText = ""
    public var selectedTagIDs: Set<UUID> = []
    public private(set) var state: LoadState = .idle
    public var pendingDeletion: VocabularyCard?
    public var pendingTagDeletion: Tag?
    public private(set) var deletionFailure: LibraryDeletionFailure?

    private let cardRepository: any CardRepository
    private let tagRepository: any TagRepository

    public init(cards: any CardRepository, tags: any TagRepository) {
        cardRepository = cards
        tagRepository = tags
    }

    public var visibleCards: [VocabularyCard] {
        let query = TextNormalizer.searchKey(searchText)

        return cards.filter { card in
            let cardTagIDs = Set(card.tags.map(\.id))
            let tagMatches = selectedTagIDs.isEmpty
                || !cardTagIDs.isDisjoint(with: selectedTagIDs)
            let textMatches = query.isEmpty
                || card.searchableValues.contains {
                    TextNormalizer.searchKey($0).contains(query)
                }

            return tagMatches && textMatches
        }
    }

    public func load() async {
        state = .loading

        do {
            let loadedCards = try await cardRepository.fetchCards()
            let loadedTags = try await tagRepository.fetchTags()
            cards = loadedCards
            tags = loadedTags
            selectedTagIDs.formIntersection(loadedTags.map(\.id))
            state = .loaded
        } catch {
            state = .failed
        }
    }

    @discardableResult
    public func deletePendingCard() async -> Bool {
        guard let card = pendingDeletion else { return false }
        deletionFailure = nil

        do {
            try await cardRepository.delete(id: card.id)
            cards.removeAll { $0.id == card.id }
            pendingDeletion = nil
            return true
        } catch {
            deletionFailure = .card
            return false
        }
    }

    @discardableResult
    public func deletePendingTag() async -> Bool {
        guard let tag = pendingTagDeletion else { return false }
        deletionFailure = nil

        do {
            try await tagRepository.delete(id: tag.id)
            tags.removeAll { $0.id == tag.id }
            selectedTagIDs.remove(tag.id)
            cards = cards.map { $0.removingTag(id: tag.id) }
            pendingTagDeletion = nil
            return true
        } catch {
            deletionFailure = .tag
            return false
        }
    }

    public func dismissDeletionFailure() {
        deletionFailure = nil
    }
}

private extension VocabularyCard {
    func removingTag(id tagID: UUID) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: russianMeanings,
            englishVariants: englishVariants,
            tags: tags.filter { $0.id != tagID },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
