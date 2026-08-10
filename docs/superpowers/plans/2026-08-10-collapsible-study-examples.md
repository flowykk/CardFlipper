# Collapsible Study Examples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move usage examples below the study assessment buttons and reveal them on demand without losing them when the current card flips.

**Architecture:** `StudySessionViewModel` owns disclosure state and resets it only when assessment advances the queue. A focused `StudyUsageExamplesView` renders current-card examples outside `StudyCardView`; sentence speech is allowed while this disclosed post-reveal section is available, independently of the visible flashcard side.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XCUITest, Tuist

## Global Constraints

- Do not change Core or SwiftData models.
- Do not show any examples before the answer has been revealed once.
- Do not show an examples control for cards without examples.
- Preserve expanded state across flips of the same card and reset it after Remember or Don't remember.
- Preserve the user's unstaged localization-catalog changes and stage only feature-specific keys.

---

### Task 1: Disclosure State and Card Presentation

**Files:**
- Modify: `Tests/StudyFeatureTests/StudySessionViewModelTests.swift`
- Modify: `Sources/StudyFeature/StudySessionViewModel.swift`
- Modify: `Sources/StudyFeature/StudyCardView.swift`

**Interfaces:**
- Consumes: `StudySession.currentCard`, `StudySession.isRevealed`, `VocabularyCard.englishVariants`
- Produces: `StudySessionViewModel.hasUsageExamples: Bool`, `isShowingUsageExamples: Bool`, `toggleUsageExamples()`

- [ ] **Step 1: Write failing behavior tests**

Add tests that create one card with an example and assert these literal transitions:

```swift
#expect(model.hasUsageExamples)
#expect(model.isShowingUsageExamples == false)
model.toggleUsageExamples()
#expect(model.isShowingUsageExamples == false)
model.toggleCardSide()
model.toggleUsageExamples()
#expect(model.isShowingUsageExamples)
model.toggleCardSide()
#expect(model.isShowingUsageExamples)
```

Add separate Remember and Don't remember tests asserting `isShowingUsageExamples == false` after the queue advances. Update card-content expectations so neither face carries usage examples.

- [ ] **Step 2: Verify RED**

Run:

```bash
tuist test StudyFeatureTests --no-selective-testing
```

Expected: compilation fails because disclosure state does not exist, proving the tests require the new behavior.

- [ ] **Step 3: Implement minimal state transitions**

Add `public private(set) var isShowingUsageExamples = false`, derive `hasUsageExamples` from the current card, and implement:

```swift
public func toggleUsageExamples() {
    guard canAssess, hasUsageExamples else { return }
    isShowingUsageExamples.toggle()
}
```

Set the property to `false` after successful `remember()` and `forget()`. Remove `usageExamples` from `StudyCardFace` and from `StudyCardView.faceValues`. Permit `speakUsageExample` only when assessment is unlocked, examples are expanded, and the IDs belong to the current card; do not couple sentence speech to the visible card side.

- [ ] **Step 4: Verify GREEN**

Run `tuist test StudyFeatureTests --no-selective-testing` and require all StudyFeature tests to pass.

---

### Task 2: Expandable Section Below Assessment Actions

**Files:**
- Create: `Sources/StudyFeature/StudyUsageExamplesView.swift`
- Modify: `Sources/StudyFeature/StudySessionView.swift`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Interfaces:**
- Consumes: `StudySessionViewModel.hasUsageExamples`, `isShowingUsageExamples`, `toggleUsageExamples()`, `speakUsageExample(variantID:exampleID:)`
- Produces: accessibility identifiers `study.examples.toggle`, `study.examples.container`, `study.usageExample`, and `study.usageExample.speak`

- [ ] **Step 1: Write the failing UI flow**

Change F4 so it finds the seeded card, reveals it, asserts the examples sentence is initially absent, taps `study.examples.toggle`, verifies the sentence and speaker, flips the card twice, and verifies the sentence remains after each flip. Then tap Remember and verify `study.examples.container` is absent for the next card.

- [ ] **Step 2: Verify RED**

Run:

```bash
tuist test CardFlipperUITests/CardFlipperFlowTests/testF4SeededUsageExampleAppearsOnEnglishStudyFace --no-selective-testing
```

Expected: failure because `study.examples.toggle` does not exist.

- [ ] **Step 3: Add the focused examples component**

Create `StudyUsageExamplesView` with a full-width bordered disclosure button using `chevron.down`/`chevron.up`, a localized count, accessibility expanded/collapsed value, and an animated list of all examples grouped in variant order. Each example shows localized part of speech, sentence, and its speech button.

In `StudySessionView`, keep `assessmentActions` first and insert the new view immediately after it when `model.hasUsageExamples`. Pass the model's disclosure binding through explicit values and callbacks rather than giving the child the model itself.

Add English and Russian catalog entries for show/hide/count/accessibility strings. Apply only those entries to the git index so unrelated catalog formatting remains unstaged.

- [ ] **Step 4: Verify focused UI GREEN**

Run the focused F4 UI test and require one passing test with zero failures.

- [ ] **Step 5: Verify the complete application**

Run:

```bash
tuist test CardFlipper --no-selective-testing
tuist build CardFlipper
```

Require the complete test suite and build to exit successfully, then commit source, tests, plan, and only the new localization keys.
