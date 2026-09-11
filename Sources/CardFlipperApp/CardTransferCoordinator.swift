import Core

struct PreparedCardExport {
    let document: CardTransferFileDocument
    let cardCount: Int
}

@MainActor
struct CardTransferCoordinator {
    private let cards: any CardRepository

    init(cards: any CardRepository) {
        self.cards = cards
    }

    func prepareExport() async throws -> PreparedCardExport {
        let cards = try await cards.fetchCards()
        return PreparedCardExport(
            document: CardTransferFileDocument(
                transfer: CardTransferDocument(cards: cards)
            ),
            cardCount: cards.count
        )
    }
}
