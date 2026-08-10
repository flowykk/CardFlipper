import Foundation
import Testing
@testable import Core
@testable import CardEditorFeature

@MainActor
@Test func newEditorStartsWithOneOrderedInputPerLanguage() {
    let model = makeNewEditor()

    #expect(model.russianMeanings.count == 1)
    #expect(model.englishVariants.count == 1)

    model.russianMeanings[0].text = "первый"
    model.addRussianMeaning()
    model.russianMeanings[1].text = "второй"
    model.addEnglishVariant()
    model.englishVariants[0].text = "first"
    model.englishVariants[1].text = "second"

    #expect(model.russianMeanings.map(\.text) == ["первый", "второй"])
    #expect(model.englishVariants.map(\.text) == ["first", "second"])
}

@MainActor
@Test func editingLoadsAllValuesAndTagSelectionsInOrder() {
    let model = CardEditorViewModel.edit(
        card: .duplicate,
        cards: CardRepositoryFake(),
        tags: TagRepositoryFake(fetchedTags: [.work]),
        dictionary: DictionaryServiceFake(),
        speech: SpeechServiceSpy(),
        now: { Date(timeIntervalSince1970: 1_000) }
    )

    #expect(model.russianMeanings.map(\.text) == ["слово"])
    #expect(model.englishVariants.map(\.text) == ["word"])
    #expect(model.englishVariants[0].ipa == "wɜːd")
    #expect(model.englishVariants[0].partsOfSpeech == [.noun])
    #expect(model.englishVariants[0].usageExamples == [
        UsageExampleInput(
            id: .editorFixture(103),
            text: "This word is useful.",
            partOfSpeech: .noun
        ),
    ])
    #expect(model.selectedTagIDs == [Tag.work.id])
}

@MainActor
@Test func addingUsageExampleRequiresAvailablePartAndAutoselectsSinglePart() {
    let model = makeNewEditor()
    let variantID = model.englishVariants[0].id

    model.addUsageExample(variantID: variantID)
    #expect(model.englishVariants[0].usageExamples.isEmpty)

    model.englishVariants[0].partsOfSpeech = [.noun]
    model.addUsageExample(variantID: variantID)

    #expect(model.englishVariants[0].usageExamples.count == 1)
    #expect(model.englishVariants[0].usageExamples[0].partOfSpeech == .noun)
}

@MainActor
@Test func addingUsageExampleWithMultiplePartsRequiresExplicitSelection() {
    let model = makeNewEditor()
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].partsOfSpeech = [.noun, .verb]

    model.addUsageExample(variantID: variantID)

    #expect(model.englishVariants[0].usageExamples[0].partOfSpeech == nil)
    #expect(model.validationErrors.contains(.missingUsageExamplePartOfSpeech) == false)
    model.englishVariants[0].usageExamples[0].text = "They work together."
    #expect(model.validationErrors.contains(.missingUsageExamplePartOfSpeech))
}

@MainActor
@Test func removingReferencedPartClearsSelectionAndPreservesSentence() {
    let model = makeNewEditor()
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].partsOfSpeech = [.noun, .verb]
    model.addUsageExample(variantID: variantID)
    let exampleID = model.englishVariants[0].usageExamples[0].id
    model.englishVariants[0].usageExamples[0].text = "They work together."
    model.chooseUsageExamplePartOfSpeech(.verb, exampleID: exampleID, variantID: variantID)

    model.togglePartOfSpeech(.verb, variantID: variantID)

    #expect(model.englishVariants[0].usageExamples[0].text == "They work together.")
    #expect(model.englishVariants[0].usageExamples[0].partOfSpeech == nil)
}

@MainActor
@Test func usageExampleSpeechUsesTrimmedCurrentSentence() {
    let speech = SpeechServiceSpy()
    let model = makeNewEditor(speech: speech)
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].partsOfSpeech = [.noun]
    model.addUsageExample(variantID: variantID)
    let exampleID = model.englishVariants[0].usageExamples[0].id
    model.englishVariants[0].usageExamples[0].text = "  This word is useful.  "

    model.speakUsageExample(id: exampleID, variantID: variantID)

    #expect(speech.spokenTexts == ["This word is useful."])
}

@MainActor
@Test func validSaveTrimsValuesPreservesOrderAndResolvesLoadedTags() async {
    let cards = CardRepositoryFake()
    let tags = TagRepositoryFake(fetchedTags: [.work, .exam])
    let model = makeNewEditor(cards: cards, tags: tags)
    await model.loadTags()
    model.russianMeanings = [
        .init(text: "  первый  "),
        .init(text: "второй"),
    ]
    model.englishVariants = [
        .init(text: " first ", ipa: " fɜːst ", partsOfSpeech: [.noun, .adj]),
        .init(text: "second", partsOfSpeech: [.adv]),
    ]
    model.selectedTagIDs = [Tag.exam.id, Tag.work.id]

    let outcome = await model.save()

    #expect(outcome == .saved)
    #expect(cards.savedCards.count == 1)
    #expect(cards.savedCards[0].russianMeanings.map(\.text) == ["первый", "второй"])
    #expect(cards.savedCards[0].englishVariants.map(\.text) == ["first", "second"])
    #expect(cards.savedCards[0].englishVariants[0].ipa == "fɜːst")
    #expect(cards.savedCards[0].englishVariants[0].partsOfSpeech == [.noun, .adj])
    #expect(cards.savedCards[0].tags == [.work, .exam])
    #expect(model.isPresented == false)
}

@MainActor
@Test func saveUsesOneSnapshotAcrossSuspendedDuplicateCheck() async throws {
    let cards = CardRepositoryFake()
    cards.suspendsDuplicateCheck = true
    let tags = TagRepositoryFake(fetchedTags: [.work, .exam])
    let model = makeNewEditor(cards: cards, tags: tags)
    await model.loadTags()
    let firstMeaningID = UUID.editorFixture(201)
    let secondMeaningID = UUID.editorFixture(202)
    let firstVariantID = UUID.editorFixture(203)
    let secondVariantID = UUID.editorFixture(204)
    model.russianMeanings = [
        .init(id: firstMeaningID, text: "  первый  "),
        .init(id: secondMeaningID, text: "второй"),
    ]
    model.englishVariants = [
        .init(
            id: firstVariantID,
            text: " first ",
            ipa: " fɜːst ",
            partsOfSpeech: [.noun],
            usageExamples: [
                .init(
                    id: .editorFixture(207),
                    text: "  The first example.  ",
                    partOfSpeech: .noun
                ),
            ]
        ),
        .init(id: secondVariantID, text: "second", partsOfSpeech: [.adj]),
    ]
    model.selectedTagIDs = [Tag.work.id]

    let saveTask = Task { await model.save() }
    #expect(await waitUntil { await cards.hasSuspendedDuplicateCheck })

    model.russianMeanings = [
        .init(id: .editorFixture(205), text: "replacement"),
    ]
    model.englishVariants = [
        .init(id: secondVariantID, text: "reordered second"),
        .init(id: .editorFixture(206), text: "replacement variant"),
        .init(id: firstVariantID, text: "reordered first"),
    ]
    model.selectedTagIDs = [Tag.exam.id]
    cards.resumeDuplicateCheck()

    #expect(await saveTask.value == .saved)
    let savedCard = try #require(cards.savedCards.first)
    #expect(savedCard.russianMeanings == [
        RussianMeaning(id: firstMeaningID, text: "первый"),
        RussianMeaning(id: secondMeaningID, text: "второй"),
    ])
    #expect(savedCard.englishVariants == [
        EnglishVariant(
            id: firstVariantID,
            text: "first",
            ipa: "fɜːst",
            partsOfSpeech: [.noun],
            usageExamples: [
                UsageExample(
                    id: .editorFixture(207),
                    text: "The first example.",
                    partOfSpeech: .noun
                ),
            ]
        ),
        EnglishVariant(
            id: secondVariantID,
            text: "second",
            ipa: nil,
            partsOfSpeech: [.adj]
        ),
    ])
    #expect(savedCard.tags == [.work])
}

@MainActor
@Test func invalidSavePreservesInputAndNeverChecksDuplicates() async {
    let cards = CardRepositoryFake()
    let model = makeNewEditor(cards: cards)
    model.russianMeanings = [.init(text: "   ")]
    model.englishVariants = [.init(text: "word", ipa: "manual")]

    let outcome = await model.save()

    #expect(outcome == .invalid)
    #expect(model.russianMeanings[0].text == "   ")
    #expect(model.englishVariants[0].ipa == "manual")
    #expect(cards.duplicateDrafts.isEmpty)
    #expect(cards.savedCards.isEmpty)
    #expect(model.isPresented == true)
}

@MainActor
@Test func duplicateRequiresExplicitConfirmation() async {
    let cards = CardRepositoryFake(duplicateResult: [.duplicate])
    let model = makeNewEditor(cards: cards)
    model.russianMeanings = [.init(text: "слово")]
    model.englishVariants = [.init(text: "word")]

    #expect(await model.save() == .needsDuplicateConfirmation)
    #expect(cards.savedCards.isEmpty)
    #expect(model.isDuplicateConfirmationPresented == true)
    #expect(model.isPresented == true)
}

@MainActor
@Test func duplicateConfirmationBypassesWarningAndSaves() async {
    let cards = CardRepositoryFake(duplicateResult: [.duplicate])
    let model = makeNewEditor(cards: cards)
    model.russianMeanings = [.init(text: "слово")]
    model.englishVariants = [.init(text: "word")]
    _ = await model.save()

    let outcome = await model.confirmDuplicateAndSave()

    #expect(outcome == .saved)
    #expect(cards.duplicateDrafts.count == 1)
    #expect(cards.savedCards.count == 1)
}

@MainActor
@Test func duplicateConfirmationSavesTheSnapshotThatWasChecked() async throws {
    let cards = CardRepositoryFake(duplicateResult: [.duplicate])
    let tags = TagRepositoryFake(fetchedTags: [.work, .exam])
    let model = makeNewEditor(cards: cards, tags: tags)
    await model.loadTags()
    let meaningID = UUID.editorFixture(211)
    let variantID = UUID.editorFixture(212)
    model.russianMeanings = [.init(id: meaningID, text: "  слово  ")]
    model.englishVariants = [
        .init(id: variantID, text: " word ", ipa: " wɜːd ", partsOfSpeech: [.noun]),
    ]
    model.selectedTagIDs = [Tag.work.id]

    #expect(await model.save() == .needsDuplicateConfirmation)

    model.russianMeanings = [
        .init(id: .editorFixture(213), text: "замена"),
    ]
    model.englishVariants = [
        .init(id: .editorFixture(214), text: "replacement", partsOfSpeech: [.verb]),
    ]
    model.selectedTagIDs = [Tag.exam.id]

    #expect(await model.confirmDuplicateAndSave() == .saved)
    let savedCard = try #require(cards.savedCards.first)
    #expect(savedCard.russianMeanings == [
        RussianMeaning(id: meaningID, text: "слово"),
    ])
    #expect(savedCard.englishVariants == [
        EnglishVariant(
            id: variantID,
            text: "word",
            ipa: "wɜːd",
            partsOfSpeech: [.noun]
        ),
    ])
    #expect(savedCard.tags == [.work])
}

@MainActor
@Test func duplicateConfirmationStillRequiresValidInput() async {
    let cards = CardRepositoryFake(duplicateResult: [.duplicate])
    let model = makeNewEditor(cards: cards)
    model.russianMeanings = [.init(text: "слово")]
    model.englishVariants = [.init(text: "word")]
    _ = await model.save()
    model.russianMeanings[0].text = "  "

    let outcome = await model.confirmDuplicateAndSave()

    #expect(outcome == .invalid)
    #expect(cards.savedCards.isEmpty)
    #expect(model.isPresented == true)
}

@MainActor
@Test func saveFailurePreservesEveryFormValueAndKeepsEditorPresented() async {
    let cards = CardRepositoryFake(saveError: .save)
    let model = makeNewEditor(cards: cards)
    model.russianMeanings = [.init(text: "  значение ")]
    model.englishVariants = [
        .init(text: " value ", ipa: " væljuː ", partsOfSpeech: [.noun, .verb]),
    ]

    let outcome = await model.save()

    #expect(outcome == .failed)
    #expect(model.russianMeanings[0].text == "  значение ")
    #expect(model.englishVariants[0].text == " value ")
    #expect(model.englishVariants[0].ipa == " væljuː ")
    #expect(model.englishVariants[0].partsOfSpeech == [.noun, .verb])
    #expect(model.saveError == .persistence)
    #expect(model.isPresented == true)
}

@MainActor
@Test func dictionarySuggestionUpdatesOnlyMatchingVariant() async {
    let dictionary = DictionaryServiceFake(
        result: .success(.init(ipa: "wɜːd", partOfSpeech: .noun))
    )
    let model = makeNewEditor(dictionary: dictionary)
    model.englishVariants = [
        .init(text: "leave", ipa: "manual", partsOfSpeech: [.verb]),
        .init(text: "word"),
    ]
    let variantID = model.englishVariants[1].id

    await model.lookup(variantID: variantID)

    #expect(model.englishVariants[0].ipa == "manual")
    #expect(model.englishVariants[0].partsOfSpeech == [.verb])
    #expect(model.englishVariants[1].ipa == "wɜːd")
    #expect(model.englishVariants[1].partsOfSpeech == [.noun])
    #expect(model.lookupState[variantID] == .suggested)
}

@MainActor
@Test func dictionaryFailurePreservesManualVariantFields() async {
    let dictionary = DictionaryServiceFake(result: .failure(.dictionary))
    let model = makeNewEditor(dictionary: dictionary)
    let variantID = model.englishVariants[0].id
    model.englishVariants[0] = .init(
        id: variantID,
        text: "word",
        ipa: "manual",
        partsOfSpeech: [.verb, .adj]
    )

    await model.lookup(variantID: variantID)

    #expect(model.englishVariants[0].ipa == "manual")
    #expect(model.englishVariants[0].partsOfSpeech == [.verb, .adj])
    #expect(model.lookupState[variantID] == .failed)
}

@MainActor
@Test func lateCancelledLookupCannotOverwriteNewerText() async {
    let dictionary = ControlledDictionaryService()
    let model = makeNewEditor(dictionary: dictionary)
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].text = "old"
    let oldLookup = Task { await model.lookup(variantID: variantID) }
    #expect(await waitUntil { await dictionary.hasRequest(for: "old") })

    model.englishVariants[0].text = "new"
    let newLookup = Task { await model.lookup(variantID: variantID) }
    #expect(await waitUntil { await dictionary.hasRequest(for: "new") })
    await dictionary.resolve(
        "new",
        with: .init(ipa: "njuː", partOfSpeech: .adj)
    )
    await newLookup.value
    #expect(model.lookupState[variantID] == .suggested)
    await dictionary.resolve(
        "old",
        with: .init(ipa: "əʊld", partOfSpeech: .noun)
    )
    await oldLookup.value

    #expect(model.englishVariants[0].text == "new")
    #expect(model.englishVariants[0].ipa == "njuː")
    #expect(model.englishVariants[0].partsOfSpeech == [.adj])
    #expect(model.lookupState[variantID] == .suggested)
}

@MainActor
@Test func schedulingLookupCancelsObsoleteDebounceForSameVariant() async {
    let dictionary = DictionaryServiceFake()
    let model = makeNewEditor(dictionary: dictionary)
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].text = "old"
    model.scheduleLookup(variantID: variantID)
    try? await Task.sleep(for: .milliseconds(50))
    model.englishVariants[0].text = "new"
    model.scheduleLookup(variantID: variantID)

    #expect(await waitUntil { await dictionary.calls.count == 1 })

    #expect(await dictionary.calls == ["new"])
}

@MainActor
@Test func scheduledLookupUsesApproximately450MillisecondDefaultDebounce() async {
    let sleepRecorder = LookupSleepRecorder()
    let model = CardEditorViewModel(
        card: nil,
        cards: CardRepositoryFake(),
        tags: TagRepositoryFake(),
        dictionary: DictionaryServiceFake(),
        speech: SpeechServiceSpy(),
        lookupSleep: { duration in
            try await sleepRecorder.sleep(for: duration)
        }
    )
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].text = "word"

    model.scheduleLookup(variantID: variantID)

    #expect(await waitUntil { await sleepRecorder.requestedDurations.count == 1 })
    #expect(await sleepRecorder.requestedDurations == [.milliseconds(450)])
}

@MainActor
@Test func editorLifecycleCancellationStopsPendingDebounceBeforeLookupStarts() async {
    let dictionary = DictionaryServiceFake()
    let sleep = ControlledLookupSleep()
    let model = CardEditorViewModel(
        card: nil,
        cards: CardRepositoryFake(),
        tags: TagRepositoryFake(),
        dictionary: dictionary,
        speech: SpeechServiceSpy(),
        lookupSleep: { duration in
            try await sleep.sleep(for: duration)
        }
    )
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].text = "word"
    model.scheduleLookup(variantID: variantID)
    #expect(await waitUntil { await sleep.hasSuspendedSleep })

    model.cancelLookupOperations()
    model.cancelLookupOperations()
    await sleep.resume()
    try? await Task.sleep(for: .milliseconds(20))

    #expect(await dictionary.calls.isEmpty)
    #expect(model.lookupState[variantID] == nil)
    #expect(model.isPresented)
}

@MainActor
@Test func editorLifecycleCancellationPropagatesAndRejectsLateInFlightResponse() async {
    let dictionary = ControlledDictionaryService()
    let model = makeNewEditor(dictionary: dictionary)
    let variantID = model.englishVariants[0].id
    model.englishVariants[0] = .init(
        id: variantID,
        text: "word",
        ipa: "manual",
        partsOfSpeech: [.verb]
    )
    let lookup = Task { await model.lookup(variantID: variantID) }
    #expect(await waitUntil { await dictionary.hasRequest(for: "word") })

    model.cancelLookupOperations()
    model.cancelLookupOperations()
    await dictionary.resolve(
        "word",
        with: .init(ipa: "wɜːd", partOfSpeech: .noun)
    )
    await lookup.value

    #expect(await dictionary.wasCancelled("word"))
    #expect(model.englishVariants[0].ipa == "manual")
    #expect(model.englishVariants[0].partsOfSpeech == [.verb])
    #expect(model.lookupState[variantID] == nil)
    #expect(model.isPresented)
}

@MainActor
@Test func speechUsesCurrentEnglishVariantText() {
    let speech = SpeechServiceSpy()
    let model = makeNewEditor(speech: speech)
    let variantID = model.englishVariants[0].id
    model.englishVariants[0].text = "  schedule  "

    model.speak(variantID: variantID)

    #expect(speech.spokenTexts == ["schedule"])
}

@MainActor
@Test func createdTagIsTrimmedLoadedSelectedAndKeepsEditorOpen() async {
    let tags = TagRepositoryFake(createdTag: .study)
    let model = makeNewEditor(tags: tags)
    model.newTagName = "  Study  "

    let outcome = await model.createTag()

    #expect(outcome == .created)
    #expect(tags.createdNames == ["Study"])
    #expect(model.availableTags == [.study])
    #expect(model.selectedTagIDs == [Tag.study.id])
    #expect(model.newTagName.isEmpty)
    #expect(model.isPresented == true)
}

@MainActor
@Test func tagCreationFailurePreservesTypedNameAndSelection() async {
    let tags = TagRepositoryFake(createError: .tags)
    let model = makeNewEditor(tags: tags)
    model.newTagName = "  Study  "
    model.selectedTagIDs = [Tag.work.id]

    let outcome = await model.createTag()

    #expect(outcome == .failed)
    #expect(model.newTagName == "  Study  ")
    #expect(model.selectedTagIDs == [Tag.work.id])
    #expect(model.tagCreationError == true)
    #expect(model.isPresented == true)
}

@MainActor
@Test func editedCardSaveExcludesItsOwnIDAndKeepsCreationDate() async {
    let cards = CardRepositoryFake()
    let model = CardEditorViewModel.edit(
        card: .duplicate,
        cards: cards,
        tags: TagRepositoryFake(fetchedTags: [.work]),
        dictionary: DictionaryServiceFake(),
        speech: SpeechServiceSpy(),
        now: { Date(timeIntervalSince1970: 1_000) }
    )

    let outcome = await model.save()

    #expect(outcome == .saved)
    #expect(cards.duplicateExclusions == [VocabularyCard.duplicate.id])
    #expect(cards.savedCards[0].id == VocabularyCard.duplicate.id)
    #expect(cards.savedCards[0].createdAt == VocabularyCard.duplicate.createdAt)
    #expect(cards.savedCards[0].updatedAt == Date(timeIntervalSince1970: 1_000))
}

@MainActor
@Test func editedCardSavePreservesExistingAndNewChildIDs() async {
    let cards = CardRepositoryFake()
    let model = CardEditorViewModel.edit(
        card: .duplicate,
        cards: cards,
        tags: TagRepositoryFake(fetchedTags: [.work]),
        dictionary: DictionaryServiceFake(),
        speech: SpeechServiceSpy(),
        now: { Date(timeIntervalSince1970: 1_000) }
    )
    model.russianMeanings[0].text = "измененное слово"
    model.addRussianMeaning()
    model.russianMeanings[1].text = "новое значение"
    model.englishVariants[0].text = "changed word"
    model.addEnglishVariant()
    model.englishVariants[1].text = "new variant"
    let newMeaningID = model.russianMeanings[1].id
    let newVariantID = model.englishVariants[1].id

    let outcome = await model.save()

    #expect(outcome == .saved)
    #expect(cards.savedCards.count == 1)
    #expect(cards.savedCards[0].russianMeanings.map(\.id) == [
        UUID.editorFixture(101),
        newMeaningID,
    ])
    #expect(cards.savedCards[0].englishVariants.map(\.id) == [
        UUID.editorFixture(102),
        newVariantID,
    ])
}
