# Learned Words Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place the learning filter below tags and animate filtering changes in the Library.

**Architecture:** Keep status filtering in `LibraryViewModel`; change only the Library view hierarchy and SwiftUI transitions. The view reads `accessibilityReduceMotion` to substitute a fade for movement.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XCUITest.

## Global Constraints

- Keep existing learned-word persistence and filtering behavior unchanged.
- Use `.snappy` motion normally and a brief opacity-only ease-in-out animation with Reduce Motion.

---

### Task 1: Animate Library filtering

**Files:**
- Modify: `Sources/LibraryFeature/LibraryView.swift`
- Test: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Interfaces:**
- Consumes: `LibraryViewModel.learningFilter`, `VocabularyCard.isLearned`.
- Produces: animated row insertion/removal and the unchanged `library.learningFilter` accessibility identifier.

- [ ] **Step 1: Write the failing UI expectation**

```swift
assertExists("library.learningFilter")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist test CardFlipper --test-targets CardFlipperUITests --no-selective-testing`

- [ ] **Step 3: Write minimal implementation**

Move the picker after `TagFilterView`, add a row `.transition(.move(edge: .top).combined(with: .opacity))`, and animate `model.learningFilter` and visible card IDs with `.snappy`; branch to `.opacity` and `.easeInOut(duration: 0.18)` when `accessibilityReduceMotion` is enabled.

- [ ] **Step 4: Run test to verify it passes**

Run: `tuist test CardFlipper --test-targets LibraryFeatureTests --test-targets CardFlipperUITests --no-selective-testing`

- [ ] **Step 5: Commit**

```bash
git add Sources/LibraryFeature/LibraryView.swift Tests/CardFlipperUITests/CardFlipperFlowTests.swift
git commit -m "feat: animate learned word filtering"
```
