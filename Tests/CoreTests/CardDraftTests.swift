import Foundation
import Testing
@testable import Core

@Test func draftReportsMissingEnglishVariant() {
    let draft = CardDraft(russianMeanings: ["слово"], englishVariants: [], tagIDs: [])
    #expect(draft.validationErrors == [.missingEnglishVariant])
}

@Test func draftReportsMissingRussianMeaning() {
    let draft = CardDraft(
        russianMeanings: [],
        englishVariants: [.init(text: "word")],
        tagIDs: []
    )
    #expect(draft.validationErrors == [.missingRussianMeaning])
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

@Test func suppliedChildIDsFollowTheirValuesThroughNormalization() throws {
    let firstMeaningID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let blankMeaningID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let blankVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let firstVariantID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let draft = CardDraft(
        russianMeanings: [" слово ", "  "],
        englishVariants: [
            .init(text: "  "),
            .init(text: " word ", ipa: " wɜːd ", partsOfSpeech: [.noun]),
        ],
        tagIDs: []
    )

    let card = try draft.makeCard(
        id: UUID(),
        russianMeaningIDs: [firstMeaningID, blankMeaningID],
        englishVariantIDs: [blankVariantID, firstVariantID],
        now: Date(timeIntervalSince1970: 1)
    )

    #expect(card.russianMeanings == [
        RussianMeaning(id: firstMeaningID, text: "слово"),
    ])
    #expect(card.englishVariants == [
        EnglishVariant(
            id: firstVariantID,
            text: "word",
            ipa: "wɜːd",
            partsOfSpeech: [.noun]
        ),
    ])
}

@Test func usageExamplesAreTrimmedOrderedAndKeepSuppliedIDs() throws {
    let firstExampleID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let blankExampleID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    let draft = CardDraft(
        russianMeanings: ["слово"],
        englishVariants: [
            .init(
                text: "word",
                partsOfSpeech: [.noun],
                usageExamples: [
                    .init(text: "  This word matters.  ", partOfSpeech: .noun),
                    .init(text: "   ", partOfSpeech: nil),
                ]
            ),
        ],
        tagIDs: []
    )

    let card = try draft.makeCard(
        id: UUID(),
        russianMeaningIDs: [UUID()],
        englishVariantIDs: [UUID()],
        usageExampleIDsByVariant: [[firstExampleID, blankExampleID]],
        now: Date(timeIntervalSince1970: 1)
    )

    #expect(card.englishVariants[0].usageExamples == [
        UsageExample(
            id: firstExampleID,
            text: "This word matters.",
            partOfSpeech: .noun
        ),
    ])
    #expect(card.searchableValues.contains("This word matters."))
}

@Test func nonemptyUsageExampleRequiresPartSelectedOnItsVariant() {
    let missingSelection = CardDraft(
        russianMeanings: ["слово"],
        englishVariants: [
            .init(
                text: "word",
                partsOfSpeech: [.noun],
                usageExamples: [.init(text: "An example.", partOfSpeech: nil)]
            ),
        ],
        tagIDs: []
    )
    let unavailableSelection = CardDraft(
        russianMeanings: ["слово"],
        englishVariants: [
            .init(
                text: "word",
                partsOfSpeech: [.noun],
                usageExamples: [.init(text: "An example.", partOfSpeech: .verb)]
            ),
        ],
        tagIDs: []
    )

    #expect(missingSelection.validationErrors == [.missingUsageExamplePartOfSpeech])
    #expect(unavailableSelection.validationErrors == [.missingUsageExamplePartOfSpeech])
}

@Test func blankUsageExampleDoesNotRequirePartOfSpeech() {
    let draft = CardDraft(
        russianMeanings: ["слово"],
        englishVariants: [
            .init(
                text: "word",
                usageExamples: [.init(text: "  ", partOfSpeech: nil)]
            ),
        ],
        tagIDs: []
    )

    #expect(draft.validationErrors.isEmpty)
}
