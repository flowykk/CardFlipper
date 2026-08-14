# Learned Words

## Goal

Let a user mark each vocabulary card as learned and use that persisted status to focus both the Library and a study session on all, learned, or unlearned cards.

## Data model and persistence

`VocabularyCard` gains a persisted `isLearned` Boolean, initially `false` for newly created cards and existing stored cards. `CardEntity`, the SwiftData mapper, and repository save path carry this value. Changing the status updates `updatedAt` so the Library ordering continues to reflect the latest change.

The transfer format includes `isLearned`. Import remains backward-compatible: a document without the field decodes every card as unlearned. Merge behavior treats the field as ordinary card state, so an imported newer card can update the status.

## Shared filter

Introduce a small status-filter type with three values: all, learned, and unlearned. Both feature view models own a selected value that defaults to all. The filter applies in addition to the existing filters:

- Library: status AND search text AND selected tags.
- Study setup: status AND selected tags.

The study configuration contains the cards after both filters have been applied. It does not need to persist the status-filter value separately because the selected card set is immutable for the duration of the session.

## Library interface

For a populated Library, a segmented selector appears above the existing tag scroll view with localized labels for All, Learned, and Unlearned. Selecting a segment immediately updates the displayed cards.

Each card row retains the current destructive swipe action for deletion and gains a non-destructive swipe action that toggles its state:

- An unlearned card exposes “Mark learned”.
- A learned card exposes “Mark unlearned”.

There is no confirmation dialog. After persistence succeeds, the row updates in place or disappears immediately when it no longer matches the selected status filter. If saving fails, the displayed card remains unchanged and the feature uses the existing Library error presentation with a retry action.

“Clear filters” resets search text, selected tags, and the status filter to all.

## Study setup interface

The study setup form places the same segmented selector before the tag selection section. It immediately changes the matching-card count and whether Start is enabled. Users can deliberately study learned cards for review, unlearned cards for new material, or both together.

## Accessibility and localization

All three filter labels, swipe-action labels, status-related errors, and any accessibility hints are localized. The segmented controls expose the selected value through standard SwiftUI semantics. Each swipe action has a stable accessibility label so VoiceOver users can mark a card learned or unlearned without opening the editor.

## Verification

Tests cover:

- default and persisted learned state, including old transfer documents without the new field;
- Library filtering, filter reset, and optimistic-visible behavior after toggling status;
- Study matching cards and configurations for each status mode, alone and combined with tag selection;
- mapper/repository round-trips and merge behavior;
- localization keys and relevant UI accessibility identifiers.

The focused test targets and the full project test suite must pass.

## Scope

The feature deliberately does not add automatic learning rules, spaced repetition, learned timestamps, progress statistics, or a status editor field. Status changes are manual and occur from Library swipe actions only.
