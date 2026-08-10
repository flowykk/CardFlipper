# Library Translation Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide Russian meanings in Library rows by default and reveal them for the current screen through a list-level toggle.

**Architecture:** `LibraryView` owns one transient `@State` Boolean and passes it into each `VocabularyCardRow` as an immutable rendering input. The row always renders English first and conditionally inserts Russian content; filtering remains in `LibraryViewModel` and is unchanged.

**Tech Stack:** Swift 6, SwiftUI, XCTest UI testing, Tuist, iOS 18+

## Global Constraints

- Translation visibility must default to hidden each time a new Library screen is created.
- Visibility must not be persisted.
- Search and tag filtering must continue to use both languages.
- Hidden Russian text must not remain in the accessibility hierarchy.
- Preserve unrelated uncommitted workspace changes.

---

### Task 1: Conditional Library Translation UI

**Files:**
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`
- Modify: `Sources/LibraryFeature/LibraryView.swift`
- Modify: `Sources/LibraryFeature/VocabularyCardRow.swift`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`

**Interfaces:**
- Consumes: `VocabularyCard` values already loaded by `LibraryViewModel.visibleCards`.
- Produces: `VocabularyCardRow.init(card:showRussianMeanings:)` and the `library.translations.toggle` accessibility identifier.

- [x] **Step 1: Write the failing UI test**

Add a seeded-library test that asserts the Russian value `книга` is absent from the first row, taps `library.translations.toggle`, and then asserts that the value appears in that row.

- [x] **Step 2: Run the focused UI test to verify RED**

Run `tuist test CardFlipper --test-targets CardFlipperUITests/CardFlipperFlowTests/testLibraryHidesTranslationsUntilToggleIsEnabled --no-selective-testing` and confirm failure because `library.translations.toggle` does not exist.

- [x] **Step 3: Implement minimal SwiftUI behavior**

Add `@State private var showsRussianMeanings = false` to `LibraryView`. Insert a first list section containing `Toggle("library.translations.show", isOn: $showsRussianMeanings)` with accessibility identifier `library.translations.toggle`. Change row creation to `VocabularyCardRow(card: card, showRussianMeanings: showsRussianMeanings)`.

Change `VocabularyCardRow` to accept `showRussianMeanings: Bool`, render English variants first using `.headline`, and include the Russian values below only inside `if showRussianMeanings`. Keep tags, the full-width hit area, and combined accessibility behavior unchanged.

Add English “Show translations” and Russian “Показывать переводы” values for `library.translations.show` to the existing string catalog without rewriting unrelated catalog entries.

- [x] **Step 4: Verify GREEN and regression safety**

Run the focused UI test, then `tuist test CardFlipper --no-selective-testing`, followed by `tuist build CardFlipper`. All commands must exit successfully with no new warnings attributable to this change.

- [x] **Step 5: Review and commit**

Inspect `git diff --check` and the scoped diff. Commit only the feature files and plan with message `feat: hide library translations by default`, leaving unrelated user changes unstaged.
