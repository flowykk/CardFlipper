# English Usage Examples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add unlimited optional English usage-example sentences, each tied to one part of speech, to every English variant and expose them in editing, persistence, search, speech, and study.

**Architecture:** Extend the existing vertical modular slice without changing MVVM boundaries. `Core` owns immutable example values and validation, `Data` owns a cascade child entity and mapping, `CardEditorFeature` owns editable nested inputs, and `StudyFeature` renders and speaks persisted examples through the existing speech service.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, Swift Testing, XCUITest, Tuist, iOS 18+.

## Global Constraints

- Examples are optional, ordered, unlimited, English-only, and manually entered.
- Every non-empty example has exactly one part of speech selected from its owning variant.
- Removing a referenced part of speech preserves the sentence and clears its selection.
- Examples appear only in the editor and on the English study face, not in Library rows.
- Example text participates in Library search but not duplicate detection.
- Use the existing speech service and add no dependencies or network calls.
- Preserve existing user changes in `Resources/CardFlipperApp/Localizable.xcstrings`.

---

### Task 1: Core example model and validation

**Files:**
- Modify: `Sources/Core/Models/VocabularyCard.swift`
- Modify: `Sources/Core/Models/CardDraft.swift`
- Modify: `Tests/CoreTests/CardDraftTests.swift`
- Modify: `Tests/CoreTests/TestFixtures.swift`

**Interfaces:**
- Produces: `UsageExample`, `UsageExampleDraft`, `EnglishVariant.usageExamples`, `EnglishVariantDraft.usageExamples`
- Produces: `CardDraft.makeCard(id:russianMeaningIDs:englishVariantIDs:usageExampleIDsByVariant:now:)`
- Consumes: existing `PartOfSpeech`, UUID child identity, and whitespace normalization rules

- [ ] **Step 1: Add failing Core tests**

Add tests proving:

```swift
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
```

The card contains one trimmed example with the supplied ID, blank rows disappear, non-empty examples without a part of speech are invalid, and a selected part not present on the variant is invalid. Verify `searchableValues` contains the sentence.

- [ ] **Step 2: Run Core tests and verify RED**

Run: `tuist test CardFlipper --test-targets CoreTests --no-selective-testing`

Expected: compile failures because example types and properties do not exist.

- [ ] **Step 3: Implement the domain values and nested identity mapping**

Add:

```swift
public struct UsageExample: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let partOfSpeech: PartOfSpeech
}

public struct UsageExampleDraft: Equatable, Sendable {
    public var text: String
    public var partOfSpeech: PartOfSpeech?
}
```

Give `EnglishVariant` and `EnglishVariantDraft` a `usageExamples` array defaulting to `[]`. Add `.missingUsageExamplePartOfSpeech` and nested ID count errors. Validate only nonblank examples, require their selected part to belong to the variant, trim and filter them during `makeCard`, and preserve positional IDs. Expand `VocabularyCard.searchableValues` with all example text.

- [ ] **Step 4: Run Core tests and verify GREEN**

Run the same Core test command. Expected: all Core tests pass.

### Task 2: SwiftData persistence and lifecycle

**Files:**
- Create: `Sources/Data/Persistence/Entities/UsageExampleEntity.swift`
- Modify: `Sources/Data/Persistence/Entities/EnglishVariantEntity.swift`
- Modify: `Sources/Data/Persistence/CardFlipperSchema.swift`
- Modify: `Sources/Data/Persistence/Mapping/VocabularyCardMapper.swift`
- Modify: `Sources/Data/Persistence/UITestVocabularySeed.swift`
- Modify: `Tests/DataTests/TestSupport.swift`
- Modify: `Tests/DataTests/SwiftDataRepositoriesTests.swift`

**Interfaces:**
- Consumes: `EnglishVariant.usageExamples`
- Produces: `UsageExampleEntity(id:text:partOfSpeechRawValue:sortIndex:)`
- Produces: cascade relationship `EnglishVariantEntity.usageExamples`

- [ ] **Step 1: Add failing repository tests**

Extend the card fixture with ordered noun and verb examples. Verify save/fetch equality, replacement deletes obsolete example entities, deleting a card leaves zero `UsageExampleEntity` rows, and a card created with no examples round-trips with an empty array.

- [ ] **Step 2: Run Data tests and verify RED**

Run: `tuist test CardFlipper --test-targets DataTests --no-selective-testing`

Expected: compile failures for the missing persistence entity and relationship.

- [ ] **Step 3: Add entity, schema registration, mapping, and cascade ownership**

Implement:

```swift
@Model
final class UsageExampleEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var partOfSpeechRawValue: String
    var sortIndex: Int
    var variant: EnglishVariantEntity?
}
```

Add a cascade relationship on `EnglishVariantEntity`, default it to an empty array for additive migration, register the entity in `CardFlipperSchema`, and map ordered examples in both directions. Add one deterministic usage example to the first UI seed card.

- [ ] **Step 4: Run Data tests and verify GREEN**

Run the same Data test command. Expected: all Data tests pass, including ownership counts.

### Task 3: Card editor state and validation behavior

**Files:**
- Modify: `Sources/CardEditorFeature/CardEditorViewModel.swift`
- Modify: `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift`
- Modify: `Tests/CardEditorFeatureTests/TestSupport.swift`

**Interfaces:**
- Produces: `UsageExampleInput(id:text:partOfSpeech:)`
- Produces: `addUsageExample(variantID:)`, `removeUsageExample(id:variantID:)`, `chooseUsageExamplePartOfSpeech(_:exampleID:variantID:)`, `speakUsageExample(id:variantID:)`
- Consumes: Core example drafts and nested ID API from Task 1

- [ ] **Step 1: Add failing ViewModel tests**

Verify that editing loads examples and IDs; adding is ignored without variant parts; one available part is automatically selected; multiple parts yield `nil`; choosing rejects parts outside the variant; removing a used variant part clears the example selection without deleting text; save preserves nested IDs/order; suspended duplicate checks save the captured example snapshot; and sentence speech trims text.

- [ ] **Step 2: Run CardEditorFeature tests and verify RED**

Run: `tuist test CardFlipper --test-targets CardEditorFeatureTests --no-selective-testing`

Expected: compile failures for missing input state and actions.

- [ ] **Step 3: Implement nested editor state and immutable save snapshots**

Add `usageExamples` to `EnglishVariantInput`, map it from existing cards, implement the four actions, clear referenced selections inside `togglePartOfSpeech`, include examples in `draft`, and capture `[[UUID]]` in `SaveSnapshot`. Route sentence speech through the existing `SpeechService` only for nonblank text.

- [ ] **Step 4: Run CardEditorFeature tests and verify GREEN**

Run the same CardEditorFeature test command. Expected: all editor tests pass.

### Task 4: Editor UI, localization, and accessibility

**Files:**
- Create: `Sources/CardEditorFeature/UsageExamplesEditor.swift`
- Modify: `Sources/CardEditorFeature/EnglishVariantsSection.swift`
- Modify: `Sources/CardEditorFeature/CardEditorView.swift`
- Modify: `Sources/CardEditorFeature/EditorAccessibilityLabels.swift`
- Modify: `Tests/CardEditorFeatureTests/EditorAccessibilityLabelsTests.swift`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`

**Interfaces:**
- Consumes: `EnglishVariantInput` bindings and ViewModel actions from Task 3
- Produces: stable identifiers `editor.english.<variant>.example.<example>.text|partOfSpeech|speak|remove`

- [ ] **Step 1: Add failing accessibility-label tests**

Add literal English/Russian expectations for speaking and removing a one-based example within a one-based variant.

- [ ] **Step 2: Run editor tests and verify RED**

Run the CardEditorFeature test command. Expected: missing accessibility label methods.

- [ ] **Step 3: Build the nested SwiftUI editor**

Create `UsageExamplesEditor` with a vertical-axis `TextField`, a part-of-speech `Menu`, 44-point speaker/remove buttons, Add Example, per-row missing-selection feedback, and disabled Add state when no variant parts exist. Wire it from `CardEditorView` through `EnglishVariantsSection` to ViewModel actions.

Add localized English and Russian strings for the section title, add action, sentence-field prompt, choose-part prompt, required-part validation, speak/remove labels, and study example heading. Preserve all pre-existing unstaged catalog content.

- [ ] **Step 4: Run editor tests and build**

Run editor tests, then `tuist build CardFlipper`. Expected: tests and compilation succeed.

### Task 5: Study presentation and example speech

**Files:**
- Modify: `Sources/StudyFeature/StudyCardView.swift`
- Modify: `Sources/StudyFeature/StudySessionView.swift`
- Modify: `Sources/StudyFeature/StudySessionViewModel.swift`
- Modify: `Tests/StudyFeatureTests/StudySessionViewModelTests.swift`
- Modify: `Tests/StudyFeatureTests/TestSupport.swift`

**Interfaces:**
- Produces: `StudyUsageExampleContent(text:partOfSpeechText:)`
- Produces: `StudySessionViewModel.speakUsageExample(variantID:exampleID:)`
- Consumes: Core examples and the existing visible-English-side guard

- [ ] **Step 1: Add failing StudyFeature tests**

Verify example content retains variant/example order and localized part labels. Verify sentence speech is ignored on the Russian face and for mismatched IDs, and spoken on either study direction whenever the English face is visible.

- [ ] **Step 2: Run StudyFeature tests and verify RED**

Run: `tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing`

Expected: compile failures for missing study example content and speech action.

- [ ] **Step 3: Render and speak examples**

Add example content to the English face presentation, render it below each owning variant with its part-of-speech label and sentence, and add a bordered speaker control. Pass `(variantID, exampleID)` from `StudyCardView` through `StudySessionView` to the ViewModel, reusing `isEnglishSideVisible` as the speech guard.

- [ ] **Step 4: Run StudyFeature tests and verify GREEN**

Run the same StudyFeature test command. Expected: all study tests pass.

### Task 6: End-to-end flow and delivery

**Files:**
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`
- Verify: all files above

**Interfaces:**
- Consumes: stable editor and study accessibility identifiers
- Produces: regression coverage for persisted examples across editor and study

- [ ] **Step 1: Extend the UI flow before final implementation verification**

In the seeded editor flow, add a noun example, type a sentence, save, reopen, and assert its value persists. In the study flow, use the deterministic seeded example and assert its text and speaker control exist on the English face.

- [ ] **Step 2: Run the focused UI tests**

Run the affected `CardFlipperUITests` methods with `--no-selective-testing`. Expected: both pass.

- [ ] **Step 3: Run the full suite and build**

Run:

```bash
tuist test CardFlipper --no-selective-testing
tuist build CardFlipper
```

Expected: every unit/UI test passes with zero failures and the app build succeeds.

- [ ] **Step 4: Verify scope and commit**

Run `git diff --check`. Review migration ownership, validation, search, speech visibility, accessibility, and the localization diff. Stage implementation files explicitly; ensure no unrelated user localization changes are accidentally included. Commit with:

```bash
git commit -m "feat: add English usage examples"
```
