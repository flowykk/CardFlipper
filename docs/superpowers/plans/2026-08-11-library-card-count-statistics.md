# Library Card Count Statistics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the forgotten metrics displayed on the statistics screen with the current number of cards in the library.

**Architecture:** `LibraryViewModel.cards` remains the source of truth. `RootView` passes its count into `StatisticsView`, whose testable metric builder produces the four cards shown by the grid; existing persisted forgotten fields remain unchanged.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, Tuist, String Catalogs.

## Global Constraints

- Count every card currently present in the loaded library.
- Remove only the `Forgotten` and `Lessons without forgetting` UI cards; do not migrate or delete their persisted data.
- Preserve unrelated uncommitted changes, especially existing string-catalog edits and `RootView` work.
- Add English and Russian localization for the new metric.

---

### Task 1: Define and test the statistics metric set

**Files:**
- Create: `Sources/StatisticsFeature/StatisticsMetric.swift`
- Create: `Tests/StatisticsFeatureTests/StatisticsMetricTests.swift`
- Modify: `Sources/StatisticsFeature/StatisticsView.swift`
- Modify: `Resources/StatisticsFeature/Localizable.xcstrings`

**Interfaces:**
- Consumes: `StudyStatistics` and `Int libraryCardCount`.
- Produces: `StatisticsMetric.makeMetrics(statistics:libraryCardCount:) -> [StatisticsMetric]` and `StatisticsView.init(statistics:progress:libraryCardCount:calendar:)`.

- [x] **Step 1: Write the failing metric test**

Assert that a statistics value and `libraryCardCount: 7` produce localization keys `statistics.lessons`, `statistics.cards`, `statistics.average`, and `statistics.libraryCards`, with library value `7`. Assert that `statistics.forgotten` and `statistics.withoutForgetting` are absent and that an empty library renders `0`.

- [x] **Step 2: Run the test to verify RED**

Run `tuist test StatisticsFeature --no-selective-testing`. Expect compilation failure because `StatisticsMetric` and the new initializer argument do not exist.

- [x] **Step 3: Implement the minimal metric builder and UI**

Create an internal `StatisticsMetric` value with `titleKey`, `value`, and `systemImage`. Build exactly four metrics, update the grid to iterate over them, and add `libraryCardCount` to the `StatisticsView` initializer. Add `statistics.libraryCards` with `Cards in library` and `Карточек в библиотеке` by merging into the existing catalog.

- [x] **Step 4: Run StatisticsFeature tests to verify GREEN**

Run `tuist test StatisticsFeature --no-selective-testing`. Expect all StatisticsFeature tests to pass.

### Task 2: Connect the loaded library count

**Files:**
- Modify: `Sources/CardFlipperApp/RootView.swift`
- Modify: `Tests/CardFlipperAppTests/AppCompositionTests.swift`

**Interfaces:**
- Consumes: `RootViewModel.library.cards.count` and the initializer created in Task 1.
- Produces: statistics navigation showing the current loaded library count.

- [x] **Step 1: Write the failing composition test**

Load a root model backed by a card repository containing two fixtures and assert its exposed `libraryCardCount` is `2`; replace repository results with an empty array, reload, and assert `0`.

- [x] **Step 2: Run the app test to verify RED**

Run `tuist test CardFlipperAppTests --no-selective-testing`. Expect compilation failure because `RootViewModel.libraryCardCount` does not exist.

- [x] **Step 3: Implement the minimal composition change**

Expose `RootViewModel.libraryCardCount` as `library.cards.count` and pass it to `StatisticsView` from the `.statistics` destination. Preserve all unrelated edits in `RootView.swift`.

- [x] **Step 4: Verify tests and build**

Run:

```bash
tuist test StatisticsFeature --no-selective-testing
tuist test CardFlipperAppTests --no-selective-testing
tuist build CardFlipper
git diff --check
```

Expect both targeted test suites and the application build to succeed, with no whitespace errors.

- [x] **Step 5: Commit only feature files**

Stage the new metric source/tests, the targeted `StatisticsView` and `RootView` hunks, and the merged localization entry. Do not stage unrelated user changes. Commit as `feat: show library card count in statistics`.
