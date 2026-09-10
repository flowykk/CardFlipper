# Local Card Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local export/import of vocabulary cards with deterministic merging by matching normalized Russian meanings.

**Architecture:** Introduce a Codable transfer document containing complete domain cards and a service that exports cards and imports them through the existing repositories. Import preserves local storage, merges any cards sharing at least one normalized Russian meaning, unions unique child values and tags, and inserts otherwise-new cards.

**Tech Stack:** Swift, SwiftUI, SwiftData, Foundation `FileDocument`, Swift Testing.

## Global Constraints

- No cloud synchronization or network dependency.
- Existing local SwiftData storage remains the source of truth.
- Matching uses `TextNormalizer.searchKey` for case-insensitive, whitespace-normalized Russian values.
- Import never deletes existing cards.
- Existing card UUID is retained when an imported card is merged into it.

---

### Task 1: Transfer document and merge engine

**Files:**
- Create: `Sources/Core/Transfer/CardTransferDocument.swift`
- Create: `Sources/Core/Transfer/CardMergeService.swift`
- Test: `Tests/CoreTests/CardTransferTests.swift`

**Interfaces:**
- `CardTransferDocument(cards: [VocabularyCard])`, Codable transfer payload.
- `CardMergeService.merge(existing: [VocabularyCard], imported: [VocabularyCard]) -> CardMergeResult`.
- `CardMergeResult.cards`, `addedCount`, `mergedCount`.

- [ ] Write tests for round-trip Codable, Russian-meaning matching, union of values/examples/tags, duplicate removal, and insertion of unrelated cards.
- [ ] Run `tuist test` for the focused Core tests and verify the new tests initially fail.
- [ ] Implement Codable DTOs for cards, meanings, variants, examples, tags, dates, and enum raw values.
- [ ] Implement merge using normalized Russian meanings; preserve the existing card ID and creation date, use the newest updated date, and deduplicate child records by normalized content.
- [ ] Run the focused Core tests and verify they pass.

### Task 2: Repository-level import/export

**Files:**
- Modify: `Sources/Core/Repositories/CardRepository.swift`
- Modify: `Sources/Data/Repositories/SwiftDataCardRepository.swift`
- Modify: `Sources/Data/Repositories/SwiftDataTagRepository.swift`
- Test: `Tests/DataTests/SwiftDataRepositoriesTests.swift`

**Interfaces:**
- Add repository operation to save a merged set of cards while resolving tags by normalized name.

- [ ] Add tests proving merged cards and new cards persist through SwiftData, and tags with the same name do not duplicate.
- [ ] Run the Data tests and verify the new tests fail before implementation.
- [ ] Implement persistence using existing mapper/repository patterns and one context save per import.
- [ ] Run Data tests and verify they pass.

### Task 3: File export/import UI

**Files:**
- Create: `Sources/CardFlipperApp/CardTransferFileDocument.swift`
- Modify: `Sources/CardFlipperApp/SettingsView.swift`
- Modify: `Sources/CardFlipperApp/RootView.swift`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`
- Test: `Tests/CardFlipperAppTests/AppCompositionTests.swift`

**Interfaces:**
- Export through `fileExporter` as `.cardflipper`.
- Import through `fileImporter` with a confirmation summary before persistence.

- [ ] Add composition tests for transfer dependencies and import summary behavior.
- [ ] Run app tests and verify the new tests fail before implementation.
- [ ] Add Settings actions, system document picker/share flow, import confirmation, and success/error alerts.
- [ ] Localize all new labels, messages, and errors in the existing catalog.
- [ ] Run app tests and verify they pass.

### Task 4: Full verification

**Files:**
- Modify: `docs/planning/features.md` if the project feature inventory requires the new capability.

- [ ] Run the complete test suite with `tuist test`.
- [ ] Run a simulator build if available and verify Settings presents export/import actions.
- [ ] Inspect the diff for accidental changes and confirm no cloud/network code was introduced.
- [ ] Commit the implementation only after fresh verification evidence.
