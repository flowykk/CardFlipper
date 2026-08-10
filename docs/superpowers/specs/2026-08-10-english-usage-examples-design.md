# English Usage Examples Design

## Goal

Allow a user to add any number of optional English usage-example sentences to each English variant of a vocabulary card. Every non-empty example identifies exactly one part of speech, can be edited and spoken aloud, and appears on the English side during study.

## User experience

### Card editor

Each English variant contains a nested **Usage Examples** section after its part-of-speech controls. The section lists ordered example rows and an Add Example button.

Each row contains:

- a multiline English sentence field;
- a menu for exactly one part of speech;
- a speaker button for the sentence;
- a destructive remove button.

Examples are optional and unlimited. Add Example is disabled while the variant has no selected parts of speech. If the variant has exactly one selected part of speech, a new example selects it automatically. With multiple available parts of speech, a new example begins without a selection and requires the user to choose one before saving.

The part-of-speech menu exposes only parts already selected for that English variant. If the user removes a part of speech referenced by examples, their sentence text and identity remain intact while their part-of-speech selection becomes empty. A visible validation message explains that every non-empty sentence needs a part of speech, and saving returns the existing invalid outcome until the user selects a replacement or removes the sentence.

Whitespace-only example rows are discarded during normalization and do not require a part of speech. Example text is trimmed on save. There is no Russian translation and no automatic dictionary or AI generation.

### Study

The English face shows every example underneath its owning English variant in saved order. Each example displays:

- its localized part-of-speech label;
- its English sentence;
- its own speaker button.

Examples appear whenever the English face is visible. This means they are part of the prompt for English-to-Russian study and part of the revealed answer for Russian-to-English study. The existing scrollable card handles long or numerous examples. Examples do not appear in Library rows.

### Search

Usage-example text participates in Library search through `VocabularyCard.searchableValues`. It does not participate in duplicate-card detection, which continues comparing only Russian meanings and English variant text.

## Domain model and validation

`Core` adds:

```swift
public struct UsageExample: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let partOfSpeech: PartOfSpeech
}
```

`EnglishVariant` owns an ordered `[UsageExample]`. `UsageExampleDraft` mirrors the editable values with an optional `PartOfSpeech`, and `EnglishVariantDraft` owns ordered example drafts.

`CardDraft.ValidationError` adds a missing-example-part-of-speech case. Validation ignores blank example text but rejects every non-empty example whose part of speech is absent or no longer belongs to its English variant. Normalization trims text, removes blank examples, and preserves supplied example identifiers in the same way existing meaning and variant identifiers are preserved.

The editor's save snapshot captures nested example IDs so suspended duplicate checks cannot save later edits and existing example IDs survive editing.

## Persistence and migration

`Data` adds `UsageExampleEntity` with:

- unique UUID;
- text;
- part-of-speech raw value;
- sort index;
- optional inverse link to `EnglishVariantEntity`.

`EnglishVariantEntity` gains a cascade-owned to-many relationship. Mapping sorts by `sortIndex` in both directions. Replacing or deleting an English variant deletes its owned examples, matching the repository's existing replace-owned-children strategy.

The schema change is additive: a new entity plus an initially empty relationship. Existing cards map to an empty examples array, so the default SwiftData lightweight migration preserves current user data without a custom transformation.

## Feature boundaries

- `Core`: immutable domain values, drafts, validation, normalization, search values.
- `Data`: SwiftData entity, schema registration, mapping, cascade lifecycle.
- `CardEditorFeature`: editable inputs, nested row actions, validation presentation, sentence speech.
- `StudyFeature`: read-only presentation and sentence speech routed through the existing speech service.
- `LibraryFeature`: no visual changes; search works automatically from expanded searchable values.

The existing modular SwiftUI + MVVM architecture remains unchanged. No third-party dependency or network service is added.

## Accessibility and localization

All example controls receive stable accessibility identifiers and meaningful labels that include their one-based variant and example positions. Text uses Dynamic Type styles. Speaker and remove controls retain at least a 44-point target. New user-facing copy is localized in English and Russian using the existing string catalog.

## Testing

The implementation follows red-green-refactor and adds coverage at each boundary:

- Core: optional empty examples, missing/invalid part-of-speech validation, trimming, ordering, and identity preservation.
- Data: ordered round trip, replacement, and cascade deletion of examples; existing cards without examples remain readable.
- CardEditorFeature: load/edit/add/remove examples, automatic single-part selection, multi-part required selection, invalidation when a used part is removed, snapshot isolation, save preservation, and speech.
- StudyFeature: example-to-variant mapping, order, part-of-speech presentation, and speech only while the English face is visible.
- UI: create or edit a seeded card, add an example, choose its part of speech, save, reopen, and confirm the example appears and can be spoken during study.

The full Tuist test suite and application build must pass. Existing user changes in `Resources/CardFlipperApp/Localizable.xcstrings` must be preserved while adding only the required localization entries.

## Out of scope

- Russian translations of example sentences;
- automatic examples from dictionary APIs or AI;
- example previews in Library rows;
- multiple parts of speech on one example;
- spaced-repetition behavior specific to examples;
- cloud sync or sharing.
