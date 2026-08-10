# Library Translation Visibility

## Goal

Make the Library useful for English recall practice by hiding Russian translations by default while keeping them one tap away.

## Interface

The first section of the populated Library list contains a toggle labeled “Show translations.” It appears above the optional tag-filter section and controls every visible vocabulary row.

When the toggle is off, a row shows its English variants as the primary text and its tags. When the toggle is on, the same row also shows its Russian meanings below the English variants. Search and tag filtering continue to use both languages regardless of translation visibility.

## State

Translation visibility is transient view state owned by `LibraryView`. Its initial value is `false`, and it is not persisted. Every newly created Library screen therefore starts with only English variants visible.

`VocabularyCardRow` receives the current visibility value as an immutable input. It does not own or persist toggle state.

## Accessibility and localization

The toggle uses a localized string and exposes a stable accessibility identifier. Hidden Russian text is absent from the row hierarchy, so VoiceOver does not announce it while translations are hidden.

## Verification

Tests cover the default hidden state and the row's conditional Russian content. Existing Library filtering, editing, and deletion behavior remains unchanged. The full test suite and app build verify integration.

## Scope

No persistence, search behavior, tag behavior, card editing, study flow, or data-model changes are included.
