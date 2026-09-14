import Foundation
import Testing
@testable import Core

@Test func transferDocumentRoundTripsCards() throws {
    let card = VocabularyCard.fixture(
        id: UUID(),
        russian: "работа",
        english: "work",
        tag: Tag(id: UUID(), name: "учёба")
    )

    let data = try JSONEncoder().encode(CardTransferDocument(cards: [card]))
    let decoded = try JSONDecoder().decode(CardTransferDocument.self, from: data)

    #expect(decoded.decodedCards() == [card])
}

@Test func transferDocumentDefaultsMissingLearnedStateToFalse() throws {
    let card = VocabularyCard.fixture(isLearned: true)
    let encoded = try JSONEncoder().encode(CardTransferDocument(cards: [card]))
    var document = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var cards = try #require(document["cards"] as? [[String: Any]])
    cards[0].removeValue(forKey: "isLearned")
    document["cards"] = cards

    let data = try JSONSerialization.data(withJSONObject: document)
    let decoded = try JSONDecoder().decode(CardTransferDocument.self, from: data)

    #expect(decoded.decodedCards().first?.isLearned == false)
}

@Test func transferDocumentReadsFilesWithoutVersionField() throws {
    let json = """
    {"cards": []}
    """

    let document = try JSONDecoder().decode(
        CardTransferDocument.self,
        from: Data(json.utf8)
    )

    #expect(document.version == 1)
    #expect(document.cards.isEmpty)
}

@Test func mergeUnitesCardsWhenRussianMeaningMatches() {
    let existing = VocabularyCard.fixture(russian: "Работа", english: "work")
    let imported = VocabularyCard.fixture(
        id: UUID(),
        russian: " работа ",
        english: "job",
        tag: Tag(id: UUID(), name: "новое")
    )

    let result = CardMergeService.merge(existing: [existing], imported: [imported])
    let merged = result.cards[0]

    #expect(result.mergedCount == 1)
    #expect(result.addedCount == 0)
    #expect(merged.id == existing.id)
    #expect(merged.englishVariants.map(\.text) == ["work", "job"])
    #expect(merged.tags.map(\.name) == ["новое"])
}

@Test func mergeAddsUnrelatedCards() {
    let existing = VocabularyCard.fixture(russian: "работа")
    let imported = VocabularyCard.fixture(id: UUID(), russian: "дом", english: "house")

    let result = CardMergeService.merge(existing: [existing], imported: [imported])

    #expect(result.addedCount == 1)
    #expect(result.mergedCount == 0)
    #expect(result.cards.count == 2)
}

@Test func mergeUsesLearnedStateFromTheNewerCard() {
    let existing = VocabularyCard.fixture(isLearned: false)
    let imported = VocabularyCard(
        id: UUID(),
        russianMeanings: existing.russianMeanings,
        englishVariants: existing.englishVariants,
        tags: [],
        createdAt: existing.createdAt,
        updatedAt: existing.updatedAt.addingTimeInterval(1),
        isLearned: true
    )

    let result = CardMergeService.merge(existing: [existing], imported: [imported])

    #expect(result.cards[0].isLearned)
}

@Test func importPreviewClassifiesFinalCardsAndExcludesUnrelatedLibraryCards() throws {
    let existing = VocabularyCard.fixture(id: UUID(), russian: "работа", english: "work")
    let unchanged = VocabularyCard.fixture(id: UUID(), russian: "книга", english: "book")
    let unrelated = VocabularyCard.fixture(id: UUID(), russian: "кот", english: "cat")
    let addition = VocabularyCard.fixture(id: UUID(), russian: "дом", english: "house")
    let update = VocabularyCard.fixture(id: UUID(), russian: "работа", english: "job")
    let preview = CardImportPreview(fileName: "words.json", existing: [existing, unchanged, unrelated],
                                    imported: [addition, update, unchanged, addition])
    #expect(preview.changes.filter { $0.kind == .added }.count == 1)
    #expect(preview.changes.filter { $0.kind == .updated }.count == 1)
    #expect(preview.changes.filter { $0.kind == .unchanged }.count == 1)
    #expect(preview.cardsToSave.count == 2)
    let changed = try #require(preview.changes.first { $0.kind == .updated })
    #expect(changed.before == existing)
    #expect(changed.card.englishVariants.map(\.text) == ["work", "job"])
}

@Test func importPreviewTreatsTimestampOnlyChangesAsUnchanged() {
    let card = VocabularyCard.fixture()
    let preview = CardImportPreview(fileName: "words.json", existing: [card],
                                    imported: [card.updating(updatedAt: card.updatedAt.addingTimeInterval(30))])
    #expect(preview.cardsToSave.isEmpty)
    #expect(preview.changes.first?.kind == .unchanged)
}

@Test func importPreviewKeepsUnrelatedCardWithCollidingIdentifier() throws {
    let id = UUID()
    let existing = VocabularyCard.fixture(id: id, russian: "работа", english: "work")
    let imported = VocabularyCard.fixture(id: id, russian: "дом", english: "house")
    let preview = CardImportPreview(fileName: "words.json", existing: [existing], imported: [imported])
    let addition = try #require(preview.cardsToSave.first)
    #expect(addition.id != existing.id)
    #expect(addition.englishVariants.map(\.text) == ["house"])
    #expect(preview.changes.first?.kind == .added)
    #expect(preview.originalCards == [existing])
}

@Test func emptyImportPreviewHasNoChanges() {
    let preview = CardImportPreview(fileName: "empty.json", existing: [.fixture()], imported: [])
    #expect(preview.changes.isEmpty)
    #expect(preview.cardsToSave.isEmpty)
}
