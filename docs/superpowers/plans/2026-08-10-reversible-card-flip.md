# Reversible Study Card Flip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the entire study-card surface toggle freely between prompt and answer while assessment remains unlocked after the first answer view.

**Architecture:** Keep `StudySession.isRevealed` as the domain fact that assessment is allowed. Add `StudySessionViewModel.isShowingAnswer` as independent presentation state, pass it into `StudyCardView`, and reset it only when assessment advances the queue.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, Swift Testing, XCUITest, Tuist 4.40.

## Global Constraints

- Preserve both RU→EN and EN→RU study directions.
- Preserve Reduce Motion crossfade and normal 0.4-second 3D flip.
- Assessment is forbidden until the answer has been viewed once.
- After first reveal, assessment remains available regardless of the currently visible face.
- The complete visual flashcard rectangle is tappable, including empty space.
- Do not modify the user's existing `Resources/CardFlipperApp/Localizable.xcstrings` change.

---

### Task 1: Separate Answer Eligibility from Visible Face

**Files:**
- Modify: `Sources/StudyFeature/StudySessionViewModel.swift`
- Modify: `Sources/StudyFeature/StudySessionView.swift`
- Modify: `Sources/StudyFeature/StudyCardView.swift`
- Modify: `Tests/StudyFeatureTests/StudySessionViewModelTests.swift`
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Interfaces:**
- Consumes: `StudySession.isRevealed`, `StudySession.reveal()`, `StudySession.remember()`, `StudySession.forget()`.
- Produces: `StudySessionViewModel.isShowingAnswer: Bool` and `StudySessionViewModel.toggleCardSide()`.

- [ ] **Step 1: Write failing ViewModel tests**

Add tests proving the first toggle reveals and shows the answer, the second toggle returns to the prompt while `canAssess` stays true, visible-English speech follows the side, and successful assessment resets `isShowingAnswer`:

```swift
model.toggleCardSide()
#expect(model.isShowingAnswer)
#expect(model.canAssess)

model.toggleCardSide()
#expect(model.isShowingAnswer == false)
#expect(model.canAssess)
```

- [ ] **Step 2: Write the failing UI flow assertion**

In F2, tap an empty coordinate inside the prompt surface, assert the answer and assessment actions appear, then tap an empty coordinate inside the answer surface and assert the prompt returns while both assessment actions remain:

```swift
let prompt = app.descendants(matching: .any)["study.card.prompt"]
prompt.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15)).tap()
assertExists("study.card.answer")
assertExists("study.remember")

let answer = app.descendants(matching: .any)["study.card.answer"]
answer.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15)).tap()
assertExists("study.card.prompt")
assertExists("study.remember")
```

- [ ] **Step 3: Run focused tests and verify RED**

Run:

```bash
tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing
```

Expected: compilation failure because `isShowingAnswer` and `toggleCardSide()` do not exist.

- [ ] **Step 4: Implement independent presentation state**

Add to `StudySessionViewModel`:

```swift
public private(set) var isShowingAnswer = false

public func toggleCardSide() {
    guard !session.isComplete else { return }
    if !session.isRevealed {
        session.reveal()
    }
    isShowingAnswer.toggle()
    feedback.perform(.reveal)
}
```

After successful `remember()` and `forget()`, set `isShowingAnswer = false`. Compute English visibility from `isShowingAnswer`, not `session.isRevealed`.

- [ ] **Step 5: Make the whole card toggleable**

Pass `isShowingAnswer` and `toggleCardSide` from `StudySessionView`. In `StudyCardView`, use visible-side state for rotations, opacity, hit testing, accessibility visibility, and focus. Remove the one-way tap guard and apply the gesture to a full-width, minimum-height container:

```swift
ZStack { ... }
    .frame(maxWidth: .infinity, minHeight: 320)
    .contentShape(Rectangle())
    .onTapGesture(perform: onToggle)
```

Expose the default accessibility toggle action on both faces.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run:

```bash
tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing
```

Expected: all StudyFeature tests pass.

- [ ] **Step 7: Run full verification**

Run:

```bash
tuist test CardFlipper --no-selective-testing
tuist build CardFlipper
git diff --check
```

Expected: all unit and four UI tests pass; app builds; no whitespace errors.

- [ ] **Step 8: Verify visually and commit**

Install on an available Simulator, open a seeded study session, tap empty card space in both directions, and capture a screenshot after returning to the prompt with assessment actions visible.

```bash
git add Sources/StudyFeature Tests/StudyFeatureTests Tests/CardFlipperUITests docs/superpowers/plans/2026-08-10-reversible-card-flip.md
git commit -m "fix: allow study cards to flip both ways"
```

