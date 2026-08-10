# Library Row Hit Area and Default Study Direction

## Goal

Improve the two most common entry points into editing and studying:

- Tapping anywhere inside a vocabulary card row in Library opens that card for editing.
- A newly opened study setup selects English to Russian by default.

## Library interaction

`VocabularyCardRow` will expand to the full width offered by its `List` row, keep its contents leading-aligned, and define that full rectangle as its content shape. The existing plain `Button` remains the sole interaction owner, preserving native accessibility behavior and swipe-to-delete actions. No transparent overlay or competing gesture will be added.

An end-to-end UI test will tap near the trailing edge of a seeded row, outside its visible text, and verify that the editor opens with the expected card.

## Default study direction

`StudySetupViewModel` will initialize `direction` to `.englishToRussian`. This makes the segmented picker display English to Russian as selected and makes the Start action immediately available whenever matching cards exist. Users can still explicitly switch to Russian to English before starting.

The choice is a fixed default, not a persisted preference. Reopening a new setup returns to English to Russian. Repeat sessions continue to use the direction of their existing configuration.

A unit test will verify the default direction, start availability, and emitted configuration. Existing direction-selection tests will continue to verify that the user can override the default.

## Scope

No visual styling, localization, persistence, navigation, filtering, or deletion behavior changes are included.
