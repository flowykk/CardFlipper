# CardFlipper Data Model

Last updated: 2026-08-09

## Domain Values

### VocabularyCard

- `id: UUID`
- `russianMeanings: [RussianMeaning]`
- `englishVariants: [EnglishVariant]`
- `tags: [Tag]`
- `createdAt: Date`
- `updatedAt: Date`

### RussianMeaning

- `id: UUID`
- `text: String`

### EnglishVariant

- `id: UUID`
- `text: String`
- `ipa: String?`
- `partsOfSpeech: [PartOfSpeech]`

### Tag

- `id: UUID`
- `name: String`

## Persistence Entities

- `CardEntity` owns ordered Russian and English child records.
- `RussianMeaningEntity` stores text and sort index.
- `EnglishVariantEntity` stores text, IPA, parts of speech, and sort index.
- `TagEntity` stores display and normalized names and participates in a many-to-many card relationship.

Deleting a card cascades to its owned meanings and English variants. Deleting a tag nullifies tag relationships and does not delete cards.

## Schema Baseline

The first release baseline includes `TagEntity.normalizedName` as a persisted unique attribute. No released build predates this field, so there is no production-store migration from the earlier development-only schema.

The app does not silently delete or recreate a store when model-container construction fails. A pre-release development store created from the earlier schema must be removed explicitly by the developer. The first shipped schema becomes the versioned migration source for any later persistence changes.

## Validation

- At least one non-empty Russian meaning.
- At least one non-empty English variant.
- Trim leading/trailing whitespace before persistence.
- Reject empty list items rather than storing them.
- Tag normalized names are unique.
- IPA and parts of speech are optional.

## Normalization

Duplicate and search matching use case-insensitive, whitespace-collapsed strings. Original user casing remains available for display. A duplicate match triggers a warning, not a hard validation failure.

## Transient Study State

`StudySession` contains its direction, initial unique-card count, queue, forgotten-tap count, selected tag identifiers, and reveal state. It is an in-memory domain value and is discarded on exit or app termination.

## Repository Contracts

- `CardRepository`: observe/fetch, create, update, delete, and find duplicate candidates.
- `TagRepository`: observe/fetch, create, and delete.
- `DictionaryService`: retrieve an optional `DictionarySuggestion` for English text.
- `SpeechService`: speak an English value using the chosen locale.
