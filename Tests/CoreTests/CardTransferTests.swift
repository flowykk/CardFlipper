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

@Test func importValidationRejectsBlankValuesAndDuplicateIdentities() throws {
    let duplicateID = UUID()
    let emptyCard = VocabularyCard(
        id: UUID(),
        russianMeanings: [RussianMeaning(id: UUID(), text: "  ")],
        englishVariants: [EnglishVariant(id: UUID(), text: "word", ipa: nil, partsOfSpeech: [])],
        tags: [],
        createdAt: .now,
        updatedAt: .now
    )
    #expect(throws: CardImportValidationError.blankRussianMeaning(cardID: emptyCard.id)) {
        try CardImportValidator.validate([emptyCard])
    }

    let first = makeTransferTestCard(id: duplicateID, russian: "первый", english: "first")
    let second = makeTransferTestCard(id: duplicateID, russian: "второй", english: "second")
    #expect(throws: CardImportValidationError.duplicateCardID(duplicateID)) {
        try CardImportValidator.validate([first, second])
    }
}

@Test func importValidationAcceptsACompleteDocument() throws {
    try CardImportValidator.validate([
        makeTransferTestCard(id: UUID(), russian: "слово", english: "word"),
    ])
}

@Test func importValidationRejectsInvalidUsageExamplePartOfSpeechAndDuplicateTagNames() throws {
    let cardID = UUID()
    let invalidExampleCard = VocabularyCard(
        id: cardID,
        russianMeanings: [RussianMeaning(id: UUID(), text: "читать")],
        englishVariants: [
            EnglishVariant(
                id: UUID(),
                text: "read",
                ipa: nil,
                partsOfSpeech: [.verb],
                usageExamples: [UsageExample(id: UUID(), text: "a read", partOfSpeech: .noun)]
            ),
        ],
        tags: [],
        createdAt: .now,
        updatedAt: .now
    )
    #expect(throws: CardImportValidationError.invalidUsageExamplePartOfSpeech(cardID: cardID)) {
        try CardImportValidator.validate([invalidExampleCard])
    }

    let base = makeTransferTestCard(id: cardID, russian: "слово", english: "word")
    let duplicateTagsCard = VocabularyCard(
        id: base.id,
        russianMeanings: base.russianMeanings,
        englishVariants: base.englishVariants,
        tags: [Tag(id: UUID(), name: "Work"), Tag(id: UUID(), name: " work ")],
        createdAt: base.createdAt,
        updatedAt: base.updatedAt
    )
    #expect(throws: CardImportValidationError.duplicateTagName(cardID: cardID)) {
        try CardImportValidator.validate([duplicateTagsCard])
    }
}

private func makeTransferTestCard(id: UUID, russian: String, english: String) -> VocabularyCard {
    VocabularyCard(
        id: id,
        russianMeanings: [RussianMeaning(id: UUID(), text: russian)],
        englishVariants: [EnglishVariant(id: UUID(), text: english, ipa: nil, partsOfSpeech: [])],
        tags: [],
        createdAt: .now,
        updatedAt: .now
    )
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

@Test func importPreviewClassifiesNewUpdatedAndUnchangedCards() {
    let unchanged = makeTransferTestCard(id: UUID(), russian: "работа", english: "work")
    let changing = makeTransferTestCard(id: UUID(), russian: "книга", english: "book")
    let importedUnchanged = unchanged
    let importedUpdate = makeTransferTestCard(id: UUID(), russian: "книга", english: "volume")
    let importedNew = makeTransferTestCard(id: UUID(), russian: "дом", english: "house")

    let preview = CardImportPreview(
        fileName: "cards.json",
        existing: [unchanged, changing],
        imported: [importedUnchanged, importedUpdate, importedNew]
    )

    #expect(preview.changes.filter { $0.kind == .added }.map(\.card.id) == [importedNew.id])
    #expect(preview.changes.filter { $0.kind == .updated }.map(\.card.id) == [changing.id])
    #expect(preview.changes.filter { $0.kind == .unchanged }.map(\.card.id) == [unchanged.id])
    #expect(preview.cardsToSave.map(\.id) == [changing.id, importedNew.id])
}

@Test func importPreviewReclassifiesMissingReplacementAsAdded() {
    let original = makeTransferTestCard(id: UUID(), russian: "слово", english: "word")
    let preview = CardImportPreview(
        fileName: "cards.json",
        existing: [original],
        imported: [original]
    )
    let edited = VocabularyCard(
        id: original.id,
        russianMeanings: [RussianMeaning(id: original.russianMeanings[0].id, text: "термин")],
        englishVariants: original.englishVariants,
        tags: original.tags,
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
        isLearned: original.isLearned
    )
    let editedPreview = preview.replacingEditedCards([edited])

    let refreshed = CardImportPreview(
        fileName: editedPreview.fileName,
        existing: [],
        imported: editedPreview.importedCards,
        replacingCardIDs: editedPreview.replacingCardIDs
    )

    #expect(refreshed.changes.count == 1)
    #expect(refreshed.changes.first?.kind == .added)
    #expect(refreshed.changes.first?.card.id == original.id)
    #expect(refreshed.changes.first?.card.russianMeanings.map(\.text) == ["термин"])
}
