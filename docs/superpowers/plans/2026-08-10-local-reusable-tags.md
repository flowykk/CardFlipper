# Local Reusable Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store each created tag in the local catalog and expose that catalog as one-tap reusable chips in every card editor.

**Architecture:** Keep `SwiftDataTagRepository` as the persistent source of truth and keep tag selection state in `CardEditorViewModel`. Add a focused SwiftUI `Layout` for wrapping chips, make catalog ordering deterministic after creation, and prove reuse at the view-model, disk-store, and UI-flow boundaries.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, Swift Testing, XCTest/XCUITest, Tuist 4.40.0, iOS 18+

## Global Constraints

- All tags remain on-device in SwiftData; no cloud sync or accounts.
- Do not add schema fields or require a data migration.
- Matching tag names remains whitespace- and case-normalized through `TextNormalizer.searchKey`.
- Preserve the user's existing uncommitted changes in `Resources/CardFlipperApp/Localizable.xcstrings`.
- Follow red-green-refactor and commit each independently working task.

## File Structure

- Create `Sources/CardEditorFeature/TagChipLayout.swift`: wrapping layout used only by the editor's reusable tag chips.
- Modify `Sources/CardEditorFeature/TagPickerSection.swift`: render the local catalog as selectable chips while retaining create/retry/error controls.
- Modify `Sources/CardEditorFeature/CardEditorViewModel.swift`: keep merged tags sorted after an upsert result.
- Modify `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift`: specify sorted insertion and reuse across editor instances.
- Modify `Tests/CardEditorFeatureTests/TestSupport.swift`: make the fake repository retain successfully created tags like the real local catalog.
- Modify `Tests/DataTests/SwiftDataRepositoriesTests.swift`: verify a tag survives recreation of a disk-backed container.
- Modify `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`: verify creation and one-tap reuse in another card.

---

### Task 1: Reusable, Deterministically Ordered Editor Catalog

**Files:**
- Modify: `Tests/CardEditorFeatureTests/TestSupport.swift`
- Modify: `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift`
- Modify: `Sources/CardEditorFeature/CardEditorViewModel.swift`

**Interfaces:**
- Consumes: `TagRepository.create(name:) async throws -> Tag` and `fetchTags() async throws -> [Tag]`.
- Produces: `CardEditorViewModel.availableTags` containing the upsert result exactly once in case-insensitive alphabetical order.

- [ ] **Step 1: Make the fake retain successful creations and write failing behavior tests**

Update the fake after a successful create:

```swift
func create(name: String) async throws -> Tag {
    createdNames.append(name)
    if let createError { throw createError }
    if !fetchedTags.contains(where: { $0.id == createdTag.id }) {
        fetchedTags.append(createdTag)
    }
    return createdTag
}
```

Add tests that create `Study` with preloaded `[Work]`, expect `[Study, Work]`, and construct a second editor with the same fake, call `loadTags()`, and expect `Study` to be available but not preselected.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
tuist test CardFlipper --no-selective-testing --test-targets CardEditorFeatureTests
```

Expected: the ordering assertion fails because `createTag()` currently appends the returned tag.

- [ ] **Step 3: Implement minimal sorted merging**

After merging the returned tag in `createTag()`, sort `availableTags`:

```swift
availableTags.sort {
    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
}
```

Keep the existing selection, input clearing, and error semantics unchanged.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the command from Step 2 and expect all `CardEditorFeatureTests` to pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CardEditorFeature/CardEditorViewModel.swift Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift Tests/CardEditorFeatureTests/TestSupport.swift
git commit -m "fix: retain reusable editor tags"
```

### Task 2: Quick-Selection Tag Chips and End-to-End Editor Flow

**Files:**
- Create: `Sources/CardEditorFeature/TagChipLayout.swift`
- Modify: `Sources/CardEditorFeature/TagPickerSection.swift`
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Interfaces:**
- Consumes: `[Tag]`, `Binding<Set<UUID>>`, and the existing create/retry callbacks.
- Produces: accessible controls identified as `editor.tag.chip.<display name>` whose selected state mirrors `selectedTagIDs`.

- [ ] **Step 1: Write a failing UI flow test**

Add a test that launches an empty in-memory app, fills the first card's required Russian and English fields, creates tag `Reusable`, saves the card, opens a second editor, finds `editor.tag.chip.Reusable` without typing the tag again, taps it, saves the second card, and expects two visible `Reusable` labels in the library.

- [ ] **Step 2: Run the UI test and verify RED**

Run:

```bash
tuist test CardFlipper --no-selective-testing --test-targets CardFlipperUITests/CardFlipperFlowTests/testF5CreatedTagIsReusableInAnotherCard
```

Expected: failure because `editor.tag.chip.Reusable` does not exist in the current list UI.

- [ ] **Step 3: Implement the wrapping layout**

Create `TagChipLayout: Layout` with configurable horizontal and vertical spacing. `sizeThatFits` should walk subview sizes, wrap before exceeding the proposed width, and return the accumulated height. `placeSubviews` should repeat the same row calculation and place every subview at the row's leading edge using `.topLeading` anchors.

Use a small internal row helper so size calculation and placement share the same wrapping rules rather than duplicating arithmetic.

- [ ] **Step 4: Render accessible selectable chips**

Replace the tag `ForEach` rows with `TagChipLayout(horizontalSpacing: 8, verticalSpacing: 8)` containing plain buttons. Each label contains the tag name and a checkmark only when selected, uses horizontal and vertical padding, a capsule fill/stroke reflecting selection, and at least a 44-point hit height.

Assign:

```swift
.accessibilityIdentifier("editor.tag.chip.\(tag.name)")
.accessibilityAddTraits(isSelected ? .isSelected : [])
```

Keep the new-tag field, plus button, loading retry, and creation error below the chip layout unchanged.

- [ ] **Step 5: Run the UI test and module tests and verify GREEN**

Run:

```bash
tuist test CardFlipper --no-selective-testing --test-targets CardEditorFeatureTests --test-targets CardFlipperUITests/CardFlipperFlowTests/testF5CreatedTagIsReusableInAnotherCard
```

Expected: both targets pass and the second card reuses the first tag without tag-name input.

- [ ] **Step 6: Commit**

```bash
git add Sources/CardEditorFeature/TagChipLayout.swift Sources/CardEditorFeature/TagPickerSection.swift Tests/CardFlipperUITests/CardFlipperFlowTests.swift
git commit -m "feat: add reusable tag chips"
```

### Task 3: Disk Persistence Regression and Full Verification

**Files:**
- Modify: `Tests/DataTests/SwiftDataRepositoriesTests.swift`

**Interfaces:**
- Consumes: `CardFlipperSchema.schema`, `ModelConfiguration(_:schema:url:allowsSave:cloudKitDatabase:)`, and `SwiftDataTagRepository`.
- Produces: a regression test proving a tag is available from a newly constructed container at the same local store URL.

- [ ] **Step 1: Add the disk-store regression test**

Create a unique temporary directory and `default.store` URL. In an inner scope, construct a disk-backed `ModelContainer`, create `Reusable`, and release the repository and container at scope exit. Construct a second container with an equivalent configuration and assert that `fetchTags()` returns the original tag. Remove the unique temporary directory in `defer`.

- [ ] **Step 2: Run the data test**

Run:

```bash
tuist test CardFlipper --no-selective-testing --test-targets DataTests
```

Expected: pass, documenting that the existing SwiftData repository already survives container recreation.

- [ ] **Step 3: Run all non-UI tests**

Run:

```bash
tuist test CardFlipper --no-selective-testing --skip-ui-tests
```

Expected: all unit and integration tests pass without warnings or failures.

- [ ] **Step 4: Run the complete suite**

Run:

```bash
tuist test CardFlipper --no-selective-testing
```

Expected: every unit and UI test passes.

- [ ] **Step 5: Review the final diff and commit the regression test**

Confirm `git diff --check` is clean and that `Resources/CardFlipperApp/Localizable.xcstrings` remains outside the feature commits, then run:

```bash
git add Tests/DataTests/SwiftDataRepositoriesTests.swift
git commit -m "test: verify local tag persistence"
```
