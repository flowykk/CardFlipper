# Tag Filter Leading Inset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the first horizontal Library tag chip with the 20-point leading inset of the “Show translations” row.

**Architecture:** Keep the list row edge-to-edge and apply a leading content margin directly to the horizontal `ScrollView`. This isolates the alignment change from chip sizing and the trailing tag-management menu.

**Tech Stack:** Swift 6, SwiftUI, XCTest UI testing, Tuist, iOS 18+

## Global Constraints

- The leading scroll-content margin is exactly 20 points.
- The trailing menu position, chip spacing, hit areas, and scroll behavior remain unchanged.
- Preserve unrelated localization catalog changes.

---

### Task 1: Tag Scroll Content Margin

**Files:**
- Modify: `Sources/LibraryFeature/TagFilterView.swift`

**Interfaces:**
- Consumes: the existing horizontal `ScrollView` containing tag filter buttons.
- Produces: a 20-point leading margin through `.contentMargins(.leading, 20, for: .scrollContent)`.

- [x] **Step 1: Apply the focused layout change**

Add `.contentMargins(.leading, 20, for: .scrollContent)` to the horizontal `ScrollView` after `.scrollIndicators(.hidden)`.

- [x] **Step 2: Verify compilation and behavior**

Run `tuist build LibraryFeature` and the existing seeded Library UI test `CardFlipperFlowTests/testLibraryHidesTranslationsUntilToggleIsEnabled`. Both commands must succeed.

- [x] **Step 3: Inspect the live Library screen**

Launch the seeded app in an available simulator and confirm the first tag aligns with the “Show translations” content while the management menu remains trailing-aligned.

- [x] **Step 4: Review and commit**

Run `git diff --check`, inspect the scoped diff, and commit only `TagFilterView.swift` and this plan with message `fix: inset library tag filters`.
