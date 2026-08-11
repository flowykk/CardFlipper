# Library Card Count in Statistics

## Goal

Replace the `Forgotten` and `Lessons without forgetting` metric cards on the statistics screen with one metric showing the current number of cards in the library.

## User Experience

The statistics metric grid contains four cards:

1. Completed lessons.
2. Cards studied.
3. Average cards per lesson.
4. Cards in library.

The library metric counts every card currently present in the library. It displays `0` for an empty library and updates after cards are added or removed. The English and Russian interfaces use localized titles.

## Architecture and Data Flow

`LibraryViewModel.cards` remains the single source of truth for the loaded library contents. `RootView` passes `model.library.cards.count` to a new `libraryCardCount` parameter of `StatisticsView`.

`StatisticsView` does not fetch from `CardRepository`, persist a duplicate count, or introduce asynchronous loading state. Observation already invalidates `RootView` when the library collection changes, so a newly opened statistics destination receives the current count.

The persisted `forgottenCount` and `lessonsWithoutForgettingCount` fields remain in `StudyStatistics` and its repository for backward compatibility. Only their metric cards are removed from the interface.

## Localization and Accessibility

Add a `statistics.libraryCards` entry to the existing StatisticsFeature string catalog with English and Russian translations. The existing combined accessibility behavior of metric cards is retained, so VoiceOver reads the numeric value and localized title together.

## Testing

- Add a testable metric presentation model or builder for the statistics grid.
- Verify the grid contains exactly the four intended metrics.
- Verify the removed localization keys are absent from the grid.
- Verify the library metric displays both a nonzero count and `0` for an empty library.
- Update app composition tests for the new `StatisticsView` input if required.
- Run `StatisticsFeatureTests`, app tests, and a full application build.

## Out of Scope

- Removing historical forgotten-session data from persistence.
- Changing study result tracking.
- Adding charts, drill-down navigation, or a separate library query.
