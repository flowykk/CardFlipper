import Foundation
import Testing
@testable import Core

@Test func draftRequiresOneValueOnBothSides() {
    let draft = CardDraft(russianMeanings: ["слово"], englishVariants: [], tagIDs: [])
    #expect(draft.validationErrors == [.missingEnglishVariant])
}

@Test func blankItemsAreRemovedFromValidatedDraft() throws {
    let draft = CardDraft(
        russianMeanings: [" слово ", "  "],
        englishVariants: [.init(text: " word ", ipa: nil, partsOfSpeech: [])],
        tagIDs: []
    )
    let card = try draft.makeCard(id: UUID(), now: Date(timeIntervalSince1970: 1))
    #expect(card.russianMeanings.map(\.text) == ["слово"])
    #expect(card.englishVariants.map(\.text) == ["word"])
}
