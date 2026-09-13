# Study History and Resume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Add unlimited local game history, read-only game details, and a single resumable game that can be continued or finalized when a new game starts.

**Architecture:** Keep the playable snapshot in the existing UserDefaults-backed session store, upgraded to a backward-compatible version 2 format with a stable session ID and immutable display metadata. Persist finalized history entries in SwiftData behind a Core repository protocol, derive history/statistics through one idempotent finalizer, and expose the feature through a new HistoryFeature framework plus root-level navigation and lifecycle coordination.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, Swift Testing, Tuist, iOS 18+

**Spec:** docs/superpowers/specs/2026-09-13-study-history-and-resume-design.md

## Global Constraints

- Support flashcard and writing study modes.
- Keep at most one resumable game.
- Retain finalized history locally without an item limit and sort it newest first.
- Do not allow history deletion or editing.
- Save immutable card and tag display labels with the game.
- Calculate first-try recall from assessed cards only; unseen and unassessed cards do not affect it.
- Add natural completions and finalized-early games to history and aggregate statistics exactly once.
- Do not double-count foreground duration already recorded by the study timer.
- Preserve existing vocabulary data and version-1 resumable snapshots.
- Support VoiceOver, Dynamic Type, sufficient contrast, minimum touch targets, and Reduce Motion.
- Preserve unrelated working-tree changes and stage only files owned by the current task.

---

## File Structure

### Core

- Create **Sources/Core/Study/StudyCardDisplaySnapshot.swift** for immutable card labels captured at session start.
- Create **Sources/Core/Study/StudyHistoryEntry.swift** for finalized history values and partial-result derivation.
- Create **Sources/Core/Repositories/StudyHistoryRepository.swift** for fetch and idempotent insert operations.
- Modify **Sources/Core/Study/StudySession.swift** and **Sources/Core/Study/WritingSession.swift** to track assessed card IDs and produce partial-safe results.
- Modify **Sources/Core/Study/StudySessionSnapshot.swift** for stable identity, activity time, assessed IDs, and display metadata.

### Data

- Create **Sources/Data/Persistence/Entities/StudyHistoryEntity.swift** for one finalized SwiftData row.
- Create **Sources/Data/Repositories/SwiftDataStudyHistoryRepository.swift** for mapping, newest-first fetch, and idempotent insertion.
- Modify **Sources/Data/Persistence/CardFlipperSchema.swift** and **Sources/Data/Persistence/ModelContainerFactory.swift** for the additive schema version.
- Modify **Sources/Data/Repositories/UserDefaultsStudySessionStore.swift** for version-1 migration and version-2 validation.

### Statistics and study

- Modify **Sources/StatisticsFeature/StudyStatistics.swift** and **Sources/StatisticsFeature/StatisticsRepository.swift** so completed and assessed card counts remain distinct.
- Modify **Sources/StudyFeature/StudySessionViewModel.swift** and **Sources/StudyFeature/WritingSessionViewModel.swift** so every snapshot carries stable identity and current metadata.
- Modify **Sources/StudyFeature/StudySessionView.swift** and **Sources/StudyFeature/WritingSessionView.swift** to rename the exit action to save-and-exit semantics.

### History feature and app composition

- Create **Sources/HistoryFeature/ResumableStudyBanner.swift**, **StudyHistoryViewModel.swift**, **StudyHistoryView.swift**, and **StudyHistoryDetailView.swift**.
- Create **Tests/HistoryFeatureTests/StudyHistoryViewModelTests.swift** and **TestSupport.swift**.
- Modify **Project.swift** to add HistoryFeature and HistoryFeatureTests.
- Create **Sources/CardFlipperApp/StudyHistoryFinalizer.swift** for ordered, retry-safe promotion of a snapshot into history/statistics.
- Modify **Sources/CardFlipperApp/AppContainer.swift** and **Sources/CardFlipperApp/RootView.swift** for injection, banners, navigation, conflict dialogs, and completion.
- Create **Resources/HistoryFeature/Localizable.xcstrings** for history screens and the reusable banner.
- Modify **Resources/CardFlipperApp/Localizable.xcstrings** and **Resources/StudyFeature/Localizable.xcstrings** for root conflict and study-exit copy.

---

### Task 1: Partial-Safe Domain Metrics

**Files:**
- Create: **Sources/Core/Study/StudyCardDisplaySnapshot.swift**
- Create: **Sources/Core/Study/StudyHistoryEntry.swift**
- Modify: **Sources/Core/Study/StudySession.swift**
- Modify: **Sources/Core/Study/WritingSession.swift**
- Test: **Tests/CoreTests/StudySessionTests.swift**
- Test: **Tests/CoreTests/WritingSessionTests.swift**
- Create test: **Tests/CoreTests/StudyHistoryEntryTests.swift**

**Interfaces:**
- Produces: **StudyCardDisplaySnapshot.init(id:title:)**
- Produces: **StudyResult.init(plannedCardCount:completedCardCount:encounteredCardIDs:repeatedCardIDs:totalAssessmentCount:elapsedSeconds:)**
- Produces: **StudyHistoryEntry** with validated counts and **recallRatePercentage**
- Produces: **StudySession.encounteredCardIDs** and **WritingSession.encounteredCardIDs**

- [ ] **Step 1: Write failing tests for full and partial history metrics**

~~~swift
@Test func partialHistoryIgnoresUnseenCardsInRecall() {
    let entry = StudyHistoryEntry(
        id: UUID(),
        startedAt: Date(timeIntervalSince1970: 100),
        completedAt: Date(timeIntervalSince1970: 160),
        mode: .flashcards,
        direction: .englishToRussian,
        selectedTagNames: ["Basics"],
        plannedCardCount: 10,
        completedCardCount: 3,
        encounteredCardCount: 4,
        repeatedCardCount: 1,
        forgottenCount: 2,
        totalAssessmentCount: 6,
        elapsedSeconds: 60,
        difficultCardTitles: ["book"]
    )

    #expect(entry.recallRatePercentage == 75)
    #expect(entry.completedCardCount == 3)
    #expect(entry.plannedCardCount == 10)
}

@Test func historyWithNoAssessedCardsHasZeroRecall() {
    let entry = StudyHistoryEntry(
        id: UUID(),
        startedAt: .distantPast,
        completedAt: .distantPast,
        mode: .writing,
        direction: .russianToEnglish,
        selectedTagNames: [],
        plannedCardCount: 2,
        completedCardCount: 0,
        encounteredCardCount: 0,
        repeatedCardCount: 0,
        forgottenCount: 0,
        totalAssessmentCount: 0,
        elapsedSeconds: 0,
        difficultCardTitles: []
    )
    #expect(entry.recallRatePercentage == 0)
}
~~~

Add session tests proving flashcard remember/forget adds the current ID to **encounteredCardIDs**, writing answer check/reveal does the same, and merely constructing either session does not.

- [ ] **Step 2: Run Core tests and verify the new symbols are missing**

Run:

~~~bash
tuist test CardFlipper --test-targets CoreTests --no-selective-testing
~~~

Expected: compilation fails because **StudyHistoryEntry**, the new result initializer, and encounter tracking do not exist.

- [ ] **Step 3: Implement immutable display and history values**

Add:

~~~swift
public struct StudyCardDisplaySnapshot: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String

    public init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
}

public struct StudyHistoryEntry: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date
    public let mode: StudyMode
    public let direction: StudyDirection
    public let selectedTagNames: [String]
    public let plannedCardCount: Int
    public let completedCardCount: Int
    public let encounteredCardCount: Int
    public let repeatedCardCount: Int
    public let forgottenCount: Int
    public let totalAssessmentCount: Int
    public let elapsedSeconds: Int
    public let difficultCardTitles: [String]

    public var recallRatePercentage: Int {
        guard encounteredCardCount > 0 else { return 0 }
        let recalled = max(0, encounteredCardCount - repeatedCardCount)
        return Int((Double(recalled) / Double(encounteredCardCount) * 100).rounded())
    }
}
~~~

Clamp every numeric input to nonnegative values, cap completed/encountered/repeated counts so impossible input cannot produce a negative recall rate, and sort/deduplicate display names deterministically while preserving first occurrence.

- [ ] **Step 4: Extend session and result state**

Add **encounteredCardIDs: Set<UUID>** to both session types. Flashcard **remember()** and **forget()** insert the current card before mutating the queue. Writing **checkResponse()**, first answer reveal, **remember()**, and **forget()** insert the current card without double counting.

Extend **StudyResult** with **plannedCardCount**, **completedCardCount**, and **encounteredCardCount**. Keep the existing **init(reviewedCardCount:...)** source-compatible by mapping its reviewed value to all three counts. Keep **uniqueCardCount** as an alias for completed count and calculate recall from encountered count:

~~~swift
public var recallRatePercentage: Int {
    guard encounteredCardCount > 0 else { return 0 }
    return Int(
        (Double(max(0, encounteredCardCount - repeatedCardCount))
            / Double(encounteredCardCount) * 100).rounded()
    )
}
~~~

- [ ] **Step 5: Run Core tests**

Run the command from Step 2. Expected: all Core tests pass, including existing result assertions through the compatibility initializer.

- [ ] **Step 6: Commit the domain metrics**

~~~bash
git add Sources/Core/Study/StudyCardDisplaySnapshot.swift Sources/Core/Study/StudyHistoryEntry.swift Sources/Core/Study/StudySession.swift Sources/Core/Study/WritingSession.swift Tests/CoreTests/StudySessionTests.swift Tests/CoreTests/WritingSessionTests.swift Tests/CoreTests/StudyHistoryEntryTests.swift
git commit -m "feat: model partial study history results"
~~~

### Task 2: Versioned Resumable Snapshot

**Files:**
- Modify: **Sources/Core/Study/StudySessionSnapshot.swift**
- Modify: **Sources/Data/Repositories/UserDefaultsStudySessionStore.swift**
- Test: **Tests/DataTests/UserDefaultsStudySessionStoreTests.swift**

**Interfaces:**
- Consumes: **StudyCardDisplaySnapshot**
- Produces: **StudySessionSnapshot.currentVersion == 2**
- Produces: **StudySessionSnapshot.sessionID**, **lastActivityAt**, **encounteredCardIDs**, **selectedTagNames**, and **cardDisplaySnapshots**
- Preserves: **UserDefaultsStudySessionStore.load() -> StudySessionSnapshot?**

- [ ] **Step 1: Add failing version-2 round-trip and version-1 migration tests**

Create a full version-2 snapshot and assert that all new fields round-trip. Update the legacy JSON test to assert:

~~~swift
#expect(snapshot.version == StudySessionSnapshot.currentVersion)
#expect(snapshot.lastActivityAt == snapshot.startedAt)
#expect(snapshot.encounteredCardIDs.isEmpty)
#expect(snapshot.selectedTagNames.isEmpty)
#expect(snapshot.cardDisplaySnapshots.isEmpty)
~~~

Load the legacy payload a second time and assert the same generated **sessionID** is returned, proving the migrated value was immediately persisted.

- [ ] **Step 2: Run Data tests and verify failure**

Run:

~~~bash
tuist test CardFlipper --test-targets DataTests --no-selective-testing
~~~

Expected: compilation fails for the new snapshot fields.

- [ ] **Step 3: Implement explicit decoding and migration**

Set **currentVersion** to 2 and add defaults to the public initializer. Decode version first:

~~~swift
let decodedVersion = try container.decode(Int.self, forKey: .version)
guard decodedVersion == 1 || decodedVersion == Self.currentVersion else {
    throw StudySessionSnapshotError.unsupportedVersion(decodedVersion)
}
version = Self.currentVersion
sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID) ?? UUID()
lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt) ?? startedAt
encounteredCardIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .encounteredCardIDs) ?? []
selectedTagNames = try container.decodeIfPresent([String].self, forKey: .selectedTagNames) ?? []
cardDisplaySnapshots = try container.decodeIfPresent(
    [StudyCardDisplaySnapshot].self,
    forKey: .cardDisplaySnapshots
) ?? []
~~~

After decoding a version-1 payload, **UserDefaultsStudySessionStore** immediately saves the normalized version-2 value so its generated session ID remains stable across launches. Continue clearing corrupt and future-version payloads. When the root model first resolves that legacy snapshot against the library, it fills missing tag/card display metadata once and saves the enriched version-2 snapshot before presenting the banner.

- [ ] **Step 4: Run Data tests**

Run the Step 2 command. Expected: all Data tests pass.

- [ ] **Step 5: Commit snapshot migration**

~~~bash
git add Sources/Core/Study/StudySessionSnapshot.swift Sources/Data/Repositories/UserDefaultsStudySessionStore.swift Tests/DataTests/UserDefaultsStudySessionStoreTests.swift
git commit -m "feat: version resumable study snapshots"
~~~

### Task 3: SwiftData History Repository

**Files:**
- Create: **Sources/Core/Repositories/StudyHistoryRepository.swift**
- Create: **Sources/Data/Persistence/Entities/StudyHistoryEntity.swift**
- Create: **Sources/Data/Repositories/SwiftDataStudyHistoryRepository.swift**
- Modify: **Sources/Data/Persistence/CardFlipperSchema.swift**
- Modify: **Sources/Data/Persistence/ModelContainerFactory.swift**
- Create test: **Tests/DataTests/SwiftDataStudyHistoryRepositoryTests.swift**
- Modify test support: **Tests/DataTests/TestSupport.swift**

**Interfaces:**
- Produces:

~~~swift
@MainActor
public protocol StudyHistoryRepository: AnyObject {
    func fetchHistory() throws -> [StudyHistoryEntry]
    @discardableResult
    func insertIfNeeded(_ entry: StudyHistoryEntry) throws -> Bool
}
~~~

- Produces: **SwiftDataStudyHistoryRepository.init(container:)**

- [ ] **Step 1: Write failing repository contract tests**

Test inserting two entries in reverse chronological order and fetching newest first. Insert the same session ID twice and assert **insertIfNeeded** returns true then false and only one row exists. Round-trip tag names and difficult-card titles containing Cyrillic and punctuation.

- [ ] **Step 2: Run Data tests and verify missing repository types**

Run:

~~~bash
tuist test CardFlipper --test-targets DataTests --no-selective-testing
~~~

Expected: compilation fails because the protocol, entity, and repository do not exist.

- [ ] **Step 3: Add the SwiftData entity and mapper**

Use a unique session identifier and explicit scalar fields. Encode string arrays as JSON data:

~~~swift
@Model
final class StudyHistoryEntity {
    @Attribute(.unique) var sessionID: UUID
    var startedAt: Date
    var completedAt: Date
    var modeRawValue: String
    var directionRawValue: String
    var selectedTagNamesData: Data
    var plannedCardCount: Int
    var completedCardCount: Int
    var encounteredCardCount: Int
    var repeatedCardCount: Int
    var forgottenCount: Int
    var totalAssessmentCount: Int
    var elapsedSeconds: Int
    var difficultCardTitlesData: Data
}
~~~

The repository uses a main-context **FetchDescriptor** sorted by **completedAt** descending and checks session ID before inserting. Mapping failures throw a typed repository error rather than dropping a row.

- [ ] **Step 4: Add additive schema versioning**

Define versioned schema enums for the existing vocabulary model list and the new list containing **StudyHistoryEntity**. Add one lightweight migration stage from version 1 to version 2, and construct both default and in-memory containers with that migration plan.

- [ ] **Step 5: Run repository and existing persistence tests**

Run the Step 2 command. Expected: all Data tests pass and the existing card/tag repository suite still constructs the container.

- [ ] **Step 6: Commit history persistence**

~~~bash
git add Sources/Core/Repositories/StudyHistoryRepository.swift Sources/Data/Persistence/Entities/StudyHistoryEntity.swift Sources/Data/Repositories/SwiftDataStudyHistoryRepository.swift Sources/Data/Persistence/CardFlipperSchema.swift Sources/Data/Persistence/ModelContainerFactory.swift Tests/DataTests/SwiftDataStudyHistoryRepositoryTests.swift Tests/DataTests/TestSupport.swift
git commit -m "feat: persist study history with SwiftData"
~~~

### Task 4: Aggregate Statistics for Partial Games

**Files:**
- Modify: **Sources/StatisticsFeature/StudyStatistics.swift**
- Modify: **Sources/StatisticsFeature/StatisticsRepository.swift**
- Modify test: **Tests/StatisticsFeatureTests/UserDefaultsStatisticsRepositoryTests.swift**
- Modify test: **Tests/StatisticsFeatureTests/StatisticsMetricTests.swift**

**Interfaces:**
- Consumes: extended **StudyResult.completedCardCount** and **encounteredCardCount**
- Produces: **StudyModeStatistics.encounteredCardCount**
- Preserves: **StatisticsRepository.record(sessionID:mode:result:)** idempotency

- [ ] **Step 1: Write failing partial-statistics tests**

Record a result with 10 planned, 3 completed, 4 encountered, and 1 repeated. Assert:

~~~swift
#expect(repository.statistics.studiedCardCount == 3)
#expect(repository.statistics.encounteredCardCount == 4)
#expect(repository.statistics.firstTryRecallPercentage == 75)
~~~

Record the same session ID again and assert all totals remain unchanged. Add a decoding test for the previous payload shape and expect **encounteredCardCount == studiedCardCount**.

- [ ] **Step 2: Run StatisticsFeature tests and verify failure**

Run:

~~~bash
tuist test CardFlipper --test-targets StatisticsFeatureTests --no-selective-testing
~~~

Expected: compilation fails because aggregate statistics have no encountered-card count.

- [ ] **Step 3: Implement the migrated aggregate field**

Add optional **encounteredCardCount** and **writingEncounteredCardCount** to the stored Codable payload for backward compatibility. Increment them from the result, expose nonoptional values in **StudyModeStatistics**, and change first-try recall to:

~~~swift
guard encounteredCardCount > 0 else { return 0 }
let recalled = max(0, encounteredCardCount - repeatedCardCount)
return Int((Double(recalled) / Double(encounteredCardCount) * 100).rounded())
~~~

Keep lesson counts and average cards per lesson based on completed cards.

- [ ] **Step 4: Run StatisticsFeature tests**

Run the Step 2 command. Expected: all statistics tests pass.

- [ ] **Step 5: Commit partial aggregate statistics**

~~~bash
git add Sources/StatisticsFeature/StudyStatistics.swift Sources/StatisticsFeature/StatisticsRepository.swift Tests/StatisticsFeatureTests/UserDefaultsStatisticsRepositoryTests.swift Tests/StatisticsFeatureTests/StatisticsMetricTests.swift
git commit -m "feat: count assessed cards in study statistics"
~~~

### Task 5: Session Snapshot Production

**Files:**
- Modify: **Sources/StudyFeature/StudySetupViewModel.swift**
- Modify: **Sources/StudyFeature/StudySessionViewModel.swift**
- Modify: **Sources/StudyFeature/WritingSessionViewModel.swift**
- Modify: **Sources/StudyFeature/StudySessionView.swift**
- Modify: **Sources/StudyFeature/WritingSessionView.swift**
- Modify: **Resources/StudyFeature/Localizable.xcstrings**
- Modify test: **Tests/StudyFeatureTests/StudySessionViewModelTests.swift**
- Modify test: **Tests/StudyFeatureTests/WritingSessionViewModelTests.swift**
- Modify test support: **Tests/StudyFeatureTests/TestSupport.swift**

**Interfaces:**
- Consumes: version-2 **StudySessionSnapshot** and encounter-tracking sessions
- Produces: both view-model initializers accept **sessionID: UUID** and **selectedTagNames: [String]**
- Produces: every persisted snapshot has current **lastActivityAt**, IDs, and immutable card titles
- Produces: exit copy with save-and-exit semantics

- [ ] **Step 1: Add failing snapshot-production tests for both modes**

For each view model, inject fixed **sessionID** and mutable **now**. Assert initial save captures session identity, tag names, and all card titles; an assessment advances **lastActivityAt** and **encounteredCardIDs**; resuming preserves the original identity and display snapshots.

Use one shared title function in production:

~~~swift
func studyCardDisplayTitle(_ card: VocabularyCard) -> String {
    let english = card.englishVariants.map(\.text)
    return english.isEmpty
        ? card.russianMeanings.map(\.text).joined(separator: " • ")
        : english.joined(separator: " • ")
}
~~~

- [ ] **Step 2: Run StudyFeature tests and verify failure**

Run:

~~~bash
tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing
~~~

Expected: compilation fails for the new initializer arguments and snapshot fields.

- [ ] **Step 3: Update study configuration metadata**

Add **selectedTagNames: [String]** to **StudyConfiguration**. In **StudySetupViewModel.configuration**, resolve selected IDs against **tags**, preserve the tag-list display order, and use an empty array for the all-cards selection.

- [ ] **Step 4: Persist complete version-2 snapshots**

Both view models accept a session ID for new games. When resuming, the snapshot ID wins. On every existing persistence point, save:

~~~swift
sessionID: snapshot?.sessionID ?? sessionID
lastActivityAt: now()
encounteredCardIDs: session.encounteredCardIDs
selectedTagNames: originalSelectedTagNames
cardDisplaySnapshots: originalCardDisplaySnapshots
~~~

Build display snapshots once when a new session begins; never regenerate them from edited cards after resume. Build **StudyResult** with separate planned, completed, and encountered counts.

- [ ] **Step 5: Change close-dialog copy semantics**

Keep the current confirmation presentation but route its destructive-looking close action to neutral **Save and Exit** styling and copy. Retain **Continue Game** as cancel. Do not add a discard action. Add exact Russian and English strings to the StudyFeature catalog and extend its localization-catalog test.

- [ ] **Step 6: Run StudyFeature tests**

Run the Step 2 command. Expected: all StudyFeature tests pass.

- [ ] **Step 7: Commit snapshot production**

~~~bash
git add Sources/StudyFeature/StudySetupViewModel.swift Sources/StudyFeature/StudySessionViewModel.swift Sources/StudyFeature/WritingSessionViewModel.swift Sources/StudyFeature/StudySessionView.swift Sources/StudyFeature/WritingSessionView.swift Resources/StudyFeature/Localizable.xcstrings Tests/StudyFeatureTests/StudySessionViewModelTests.swift Tests/StudyFeatureTests/WritingSessionViewModelTests.swift Tests/StudyFeatureTests/LocalizationCatalogTests.swift Tests/StudyFeatureTests/TestSupport.swift
git commit -m "feat: capture resumable study metadata"
~~~

### Task 6: History Feature UI

**Files:**
- Create: **Sources/HistoryFeature/ResumableStudyBanner.swift**
- Create: **Sources/HistoryFeature/StudyHistoryViewModel.swift**
- Create: **Sources/HistoryFeature/StudyHistoryView.swift**
- Create: **Sources/HistoryFeature/StudyHistoryDetailView.swift**
- Create: **Tests/HistoryFeatureTests/StudyHistoryViewModelTests.swift**
- Create: **Tests/HistoryFeatureTests/TestSupport.swift**
- Create: **Tests/HistoryFeatureTests/LocalizationCatalogTests.swift**
- Modify: **Project.swift**
- Create: **Resources/HistoryFeature/Localizable.xcstrings**

**Interfaces:**
- Consumes: **StudyHistoryRepository**, **StudyHistoryEntry**, **StudySessionSnapshot**
- Produces:

~~~swift
public struct ResumableStudyBanner: View {
    public init(snapshot: StudySessionSnapshot, onResume: @escaping () -> Void)
}

@MainActor @Observable
public final class StudyHistoryViewModel {
    public private(set) var entries: [StudyHistoryEntry] = []
    public private(set) var state: LoadingState = .idle
    public func load()
}

public struct StudyHistoryView: View {
    public init(
        model: StudyHistoryViewModel,
        resumableSnapshot: StudySessionSnapshot?,
        onResume: @escaping () -> Void
    )
}
~~~

- [ ] **Step 1: Add the target and failing view-model tests**

Add **HistoryFeature** as a static framework depending on Core and DesignSystem, with resources at **Resources/HistoryFeature/**. Add **HistoryFeatureTests**, include the test target in the shared scheme, and add tests for loaded, empty, failed, retry, and newest-first states.

- [ ] **Step 2: Generate and run HistoryFeature tests**

Run:

~~~bash
tuist generate --no-open
tuist test CardFlipper --test-targets HistoryFeatureTests --no-selective-testing
~~~

Expected: compilation fails because the feature types do not exist.

- [ ] **Step 3: Implement the banner**

Use one full-width **HapticButton** with **Color.accentColor** as its background and **AccessibleAccent.preferredForegroundColor(over:scheme:)** for foreground contrast. Show mode, localized progress, a relative **lastActivityAt**, and **Continue**. Give the combined element a label equivalent to “Writing, 3 of 10 cards, active 5 minutes ago, Continue” and identifier **study.resume.banner**.

- [ ] **Step 4: Implement history list and details**

The list has an optional resumable section, then finalized rows using **NavigationLink(value:)** or a private entry destination. Rows show completed date/time, mode, progress, and recall. Details render the spec fields, show **All Cards** for no tags, and omit the difficult-card section when empty.

Use **ContentUnavailableView** for empty and failed states. The failed state includes a retry button calling **load()**. Resolve feature strings from **Bundle.module**.

- [ ] **Step 5: Add exact Russian and English strings**

Add keys for history title, empty and failure states, modes, direction, progress, recall, dates, duration, tags, all cards, difficult cards, continue, and last activity. Add a localization-catalog test that resolves every key in Russian and English without returning the key.

- [ ] **Step 6: Run HistoryFeature tests and build**

Run:

~~~bash
tuist test CardFlipper --test-targets HistoryFeatureTests --no-selective-testing
tuist build HistoryFeature
~~~

Expected: both commands pass.

- [ ] **Step 7: Commit the history feature**

~~~bash
git add Project.swift Sources/HistoryFeature Tests/HistoryFeatureTests Resources/HistoryFeature/Localizable.xcstrings
git commit -m "feat: add study history screens"
~~~

### Task 7: Idempotent Finalization and Root Lifecycle

**Files:**
- Create: **Sources/CardFlipperApp/StudyHistoryFinalizer.swift**
- Modify: **Sources/CardFlipperApp/AppContainer.swift**
- Modify: **Sources/CardFlipperApp/RootView.swift**
- Modify: **Project.swift**
- Modify: **Resources/CardFlipperApp/Localizable.xcstrings**
- Modify test: **Tests/CardFlipperAppTests/AppCompositionTests.swift**
- Modify test support: **Tests/CardFlipperAppTests/TestSupport.swift**

**Interfaces:**
- Consumes: **StudyHistoryRepository**, **StatisticsRepository**, **StudySessionStore**
- Produces:

~~~swift
@MainActor
final class StudyHistoryFinalizer {
    func finalize(_ snapshot: StudySessionSnapshot, completedAt: Date) throws -> StudyHistoryEntry
}
~~~

- Produces: root methods **requestStartStudy(_:)**, **continueInterruptedStudy()**, **replaceInterruptedStudy()**, **saveAndExitStudy(sessionID:)**, and **recordCompletedStudy(sessionID:mode:result:)**

- [ ] **Step 1: Write failing finalizer tests**

Build spies that record call order. Assert successful finalization calls history insert, statistics record, then snapshot clear. Assert a thrown history insert leaves statistics untouched and the snapshot present. Assert retry after an already-inserted entry still records statistics and clears the snapshot because both stores deduplicate by session ID.

- [ ] **Step 2: Write failing root-state tests**

Cover:

- initial load exposes a resumable snapshot without presenting an alert;
- requesting a new configured game stores it as pending and presents conflict state;
- continue clears pending configuration and opens the saved session;
- cancel clears only pending state;
- replace finalizes the old snapshot before starting the pending configuration;
- replace failure retains the old snapshot and pending configuration;
- natural completion finalizes immediately and only once;
- save-and-exit ends timer/presentation but does not clear the snapshot;
- a snapshot with no available queued cards is finalized rather than discarded.

- [ ] **Step 3: Run CardFlipperApp tests and verify failure**

Run:

~~~bash
tuist test CardFlipper --test-targets CardFlipperAppTests --no-selective-testing
~~~

Expected: compilation fails because finalizer and conflict-state APIs do not exist.

- [ ] **Step 4: Implement snapshot-to-history derivation**

Map difficult IDs through **cardDisplaySnapshots**, calculate completed IDs from original IDs minus persisted queue IDs, and use stored encountered IDs for recall. Use **snapshot.completedResult** for natural completion and derived partial counts otherwise. Implement the two labeled initializers below as internal extensions in **StudyHistoryFinalizer.swift** so the mapping has one owner. The finalizer sequence is:

~~~swift
let result = StudyResult(finalizing: snapshot)
let entry = StudyHistoryEntry(
    finalizing: snapshot,
    result: result,
    completedAt: completedAt
)
_ = try history.insertIfNeeded(entry)
statistics.record(
    sessionID: snapshot.sessionID,
    mode: snapshot.mode,
    result: result
)
sessionStore.clear()
return entry
~~~

Do not clear the snapshot in a **defer** block.

- [ ] **Step 5: Inject history dependencies**

Construct **SwiftDataStudyHistoryRepository** in **AppContainer**, expose it as **any StudyHistoryRepository**, and construct the finalizer in **RootViewModel**. Add HistoryFeature to the app and app-test dependencies in **Project.swift**.

- [ ] **Step 6: Replace root lifecycle behavior**

Add **AppRoute.history** and toolbar history action. Remove the launch-time resume alert. Expose the snapshot for the reusable banner and place it above library content with a top safe-area inset.

Change study setup start callback to **requestStartStudy**. If there is no resumable snapshot, start immediately. Otherwise retain the selected configuration and present a system alert with continue, start new, and cancel actions.

Pass stable **sessionID** into both session view models. The session close callback calls **saveAndExitStudy** and leaves storage intact. The natural completion callback loads the latest snapshot and calls the finalizer immediately; a duplicate callback is harmless.

Add the history destination with a fresh **StudyHistoryViewModel**, the current resumable snapshot, and the same resume action used by the library banner.

Add exact Russian and English app-catalog keys for the history toolbar action, new-game conflict title/message/actions, finalization failure/retry, and cancel.

- [ ] **Step 7: Surface retryable failures**

Store a typed root presentation error. On finalization failure, show a localized alert with **Retry** and **Cancel**; retry repeats the same snapshot/session ID. Never start the pending new game until retry succeeds.

- [ ] **Step 8: Run app tests**

Run the Step 3 command. Expected: all CardFlipperAppTests pass.

- [ ] **Step 9: Commit lifecycle integration**

~~~bash
git add Sources/CardFlipperApp/StudyHistoryFinalizer.swift Sources/CardFlipperApp/AppContainer.swift Sources/CardFlipperApp/RootView.swift Tests/CardFlipperAppTests/AppCompositionTests.swift Tests/CardFlipperAppTests/TestSupport.swift Project.swift Resources/CardFlipperApp/Localizable.xcstrings
git commit -m "feat: integrate resumable games with history"
~~~

### Task 8: End-to-End Accessibility and Regression Verification

**Files:**
- Modify: **Tests/CardFlipperUITests/CardFlipperFlowTests.swift**
- Modify: **Tests/CardFlipperUITests/AccessibilityLayoutTests.swift**

**Interfaces:**
- Consumes: completed feature APIs and accessibility identifiers
- Produces: regression coverage for save/resume, replacement, history, detail, localization, and accessibility

- [ ] **Step 1: Add deterministic UI launch support**

Extend the existing UI-test configuration so one flag seeds a fixed resumable flashcard snapshot and another seeds two fixed history entries. Use the in-memory SwiftData container and isolated UserDefaults suite already used by UI tests. IDs and timestamps must be fixed so assertions are stable.

- [ ] **Step 2: Write the save-and-resume UI flow**

Launch seeded vocabulary, start a two-card game, assess one card, close, confirm save-and-exit, assert **study.resume.banner** says “1 of 2”, tap it, and assert the study progress resumes on the remaining card.

- [ ] **Step 3: Write the replace-old-game UI flow**

Create a resumable game, configure a writing game, press Start, assert the three conflict actions, choose Start New, finish or exit the new presentation, open history, and assert the old row shows partial progress and no early-completion badge.

- [ ] **Step 4: Write history/detail UI coverage**

Launch fixed history, open the toolbar history button, assert newest-first row order, open the newest entry, and verify mode, direction, tags, duration, progress, recall, and difficult-card labels.

- [ ] **Step 5: Add accessibility-size assertions**

At an accessibility Dynamic Type size, verify the library banner, conflict buttons, history rows, and detail metrics remain hittable and do not horizontally clip. Reuse the existing screenshot/coordinate helpers in **AccessibilityLayoutTests**.

- [ ] **Step 6: Run focused UI tests**

Run:

~~~bash
tuist test CardFlipper --test-targets CardFlipperUITests --no-selective-testing
~~~

Expected: all UI tests pass.

- [ ] **Step 7: Run the complete verification suite**

Run:

~~~bash
tuist generate --no-open
tuist test CardFlipper --no-selective-testing
tuist build CardFlipper
git diff --check
~~~

Expected: every command exits successfully with no new warnings attributable to this feature.

- [ ] **Step 8: Inspect the final diff**

Run:

~~~bash
git status --short
git diff --stat HEAD
git diff HEAD -- Sources/Core Sources/Data Sources/HistoryFeature Sources/StudyFeature Sources/StatisticsFeature Sources/CardFlipperApp Tests Project.swift Resources/CardFlipperApp/Localizable.xcstrings
~~~

Confirm that all spec requirements have corresponding code/tests and that unrelated pre-existing changes were neither reverted nor staged.

- [ ] **Step 9: Commit end-to-end coverage**

~~~bash
git add Tests/CardFlipperUITests/CardFlipperFlowTests.swift Tests/CardFlipperUITests/AccessibilityLayoutTests.swift
git commit -m "test: cover study history and resume flows"
~~~
