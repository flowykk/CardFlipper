import Foundation

public protocol CardImportRepository: Sendable {
    @MainActor
    func importCards(
        _ cards: [VocabularyCard],
        replacingCardIDs: Set<UUID>
    ) async throws -> CardMergeResult
}

public extension CardImportRepository {
    @MainActor
    func importCards(_ cards: [VocabularyCard]) async throws -> CardMergeResult {
        try await importCards(cards, replacingCardIDs: [])
    }
}
