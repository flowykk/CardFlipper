# Library Row Hit Area and Default Study Direction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each Library card row tappable across its full width and preselect English to Russian for every new study setup.

**Architecture:** Preserve the existing `Button`-owned Library interaction and expand only its label layout and content shape. Keep study-direction initialization in `StudySetupViewModel`, which remains the single source of truth for picker selection and generated configuration.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XCUITest, Tuist.

## Global Constraints

- Preserve the native Library `Button`, accessibility behavior, and swipe-to-delete actions.
- The default is fixed at English to Russian and is not persisted.
- Repeated sessions continue using their existing `StudyConfiguration`.
- Do not modify `Resources/CardFlipperApp/Localizable.xcstrings`.

---

### Task 1: Default study direction

**Files:**
- Modify: `Tests/StudyFeatureTests/StudySetupViewModelTests.swift`
- Modify: `Sources/StudyFeature/StudySetupViewModel.swift`

**Interfaces:**
- Consumes: `StudyDirection.englishToRussian`, `StudySetupViewModel.configuration`
- Produces: `StudySetupViewModel.direction` initialized to `.englishToRussian`

- [ ] **Step 1: Replace the explicit-direction test with a default-direction test**

```swift
@MainActor
@Test func setupDefaultsToEnglishToRussianAndCanStart() {
    let model = StudySetupViewModel(cards: [.fixture(id: 1)], tags: [])

    #expect(model.direction == .englishToRussian)
    #expect(model.canStart)
    #expect(model.configuration?.direction == .englishToRussian)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing`

Expected: FAIL because `direction` is `nil`, `canStart` is false, and no configuration exists.

- [ ] **Step 3: Set the model default**

In `StudySetupViewModel.init`, replace `direction = nil` with:

```swift
direction = .englishToRussian
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing`

Expected: all StudyFeature tests pass, including the existing explicit override tests.

### Task 2: Full-width Library row interaction

**Files:**
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`
- Modify: `Sources/LibraryFeature/VocabularyCardRow.swift`

**Interfaces:**
- Consumes: the existing `Button` in `LibraryView.cardList`
- Produces: a full-width rectangular hit area from `VocabularyCardRow`

- [ ] **Step 1: Change the seeded Library UI test to tap blank trailing space**

Add a helper that taps near the screen's trailing edge at the row's vertical midpoint:

```swift
private func tapTrailingEmptySpace(in row: XCUIElement) {
    let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
    origin.withOffset(
        CGVector(dx: app.frame.width - 24, dy: row.frame.midY)
    ).tap()
}
```

Use this helper instead of `firstCard.tap()` and retain the existing assertions that the correct editor content appears.

- [ ] **Step 2: Run the affected UI test and verify RED**

Run: `tuist test CardFlipper --test-targets CardFlipperUITests/CardFlipperFlowTests/testF1SeededLibraryReopensPrefilledEditor --no-selective-testing`

Expected: FAIL because tapping outside the current intrinsic label width does not open the editor.

- [ ] **Step 3: Expand the row before defining its hit shape**

In `VocabularyCardRow.body`, place this modifier before `.contentShape(Rectangle())`:

```swift
.frame(maxWidth: .infinity, alignment: .leading)
```

- [ ] **Step 4: Run the affected UI test and verify GREEN**

Run the same focused UI command. Expected: the editor opens and its seeded values match.

### Task 3: Regression verification and delivery

**Files:**
- Verify all files from Tasks 1 and 2.

**Interfaces:**
- Consumes: completed behavior from Tasks 1 and 2
- Produces: verified app build and regression suite

- [ ] **Step 1: Run all tests**

Run: `tuist test CardFlipper --no-selective-testing`

Expected: all unit and UI tests pass with zero failures.

- [ ] **Step 2: Build the app**

Run: `tuist build CardFlipper`

Expected: `Build Succeeded`.

- [ ] **Step 3: Verify scope and commit**

Run `git diff --check` and confirm `Localizable.xcstrings` remains unstaged. Stage only the four implementation/test files and this plan, then commit with:

```bash
git commit -m "fix: improve library and study defaults"
```
