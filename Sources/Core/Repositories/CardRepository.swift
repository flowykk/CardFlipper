import Foundation

public protocol CardRepository: Sendable {
    @MainActor func fetchCards() async throws -> [VocabularyCard]
    @MainActor func save(_ card: VocabularyCard) async throws
    @MainActor func delete(id: UUID) async throws
    @MainActor func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard]
}
