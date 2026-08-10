# Local Reusable Tags Design

## Goal

Make tags reliably reusable across vocabulary cards. After a user creates a tag once, the app stores it locally and presents it as a one-tap choice when creating or editing any other card.

## Current State and Problem

The app already models tags as independent SwiftData entities and the repository can create and fetch them. Existing repository and editor unit tests pass, but the editor exposes tags as a plain form list and the test suite does not cover the complete user flow from tag creation to reuse in another card. The feature therefore lacks both an explicit quick-selection experience and an end-to-end persistence guarantee.

## User Experience

The Tags section in the card editor shows every locally stored tag as a compact selectable chip. Selected chips use a filled accent treatment and an accessibility selected state; unselected chips use a neutral outlined treatment. Tapping a chip adds or removes that tag from the current card without editing text.

Below the chips, the existing text field lets the user create a tag. Submitting a non-empty name creates the tag locally and selects it immediately. If the entered name matches an existing tag after whitespace and case normalization, the app selects that existing tag instead of creating a duplicate. On the next new or edited card, the same tag appears in the chip list and can be selected with one tap.

Tags remain stored independently of cards. Cancelling a card after creating a tag does not delete the tag. Deleting a card does not delete its tags. Explicit tag deletion from tag management remains the only way to remove a tag from the local catalog.

## Architecture and Data Flow

`SwiftDataTagRepository` remains the single source of truth for the local tag catalog. Its existing create operation is an upsert by normalized name and persists new `TagEntity` values using the app's disk-backed `ModelContainer`.

`CardEditorViewModel` loads the catalog when the editor appears. Creation returns either the newly persisted tag or an existing normalized match, merges it into `availableTags`, keeps the catalog deterministically sorted, selects the returned identifier, and clears the input only after success.

`TagPickerSection` renders the catalog with a wrapping chip layout suitable for short labels and narrow iPhone widths. It owns no persistence logic: selection continues to flow through `selectedTagIDs`, while creation and retry actions remain callbacks to the view model.

Saving a card resolves its selected identifiers against the loaded catalog and passes the selected domain tags to `CardRepository`. Existing SwiftData relationships continue to associate cards and tags without duplicating tag entities.

## Error Handling

- Empty or whitespace-only names do nothing and never call persistence.
- A repository creation failure preserves the typed name and existing selection and displays the current inline failure message.
- A catalog load failure preserves any tags already available from an edited card and offers the existing retry action.
- Reusing an existing normalized name is a successful selection, not an error.

## Testing

- Editor view-model tests verify that a created or reused tag is selected, inserted only once, sorted predictably, and available to a second editor backed by the same repository.
- Data tests verify disk-backed persistence across destruction and recreation of `ModelContainer` instances at the same store URL.
- A UI test covers the visible flow: create and save a first card with a tag, open a second-card editor, select the remembered tag without typing it again, save, and verify the tag is associated with both cards.
- Existing editor, data, app-composition, and UI tests must remain green.

## Scope

This change does not add cloud sync, accounts, tag colors, frequency tracking, recency sorting, or schema fields. Alphabetical sorting is retained to avoid a migration and keep behavior predictable.
