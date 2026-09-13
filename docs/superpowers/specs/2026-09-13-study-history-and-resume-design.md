# Study History and Resumable Game Design

**Date:** 2026-09-13  
**Status:** Approved product design

## Goal

Add a local, unlimited history of study games and replace the current launch-time resume prompt with a persistent, user-initiated resume flow. A user can leave one game unfinished, see it on the library screen and in history, resume it later, or close it into history when starting a new game.

The feature applies equally to flashcard and writing study modes.

## Product Rules

- At most one resumable game may exist.
- Leaving a game through its close control saves it as resumable; it does not add it to completed history yet.
- A resumable game is visible as an accent-colored banner on the library screen and at the top of the history screen.
- Tapping either banner resumes the saved game immediately.
- Starting a configured new game while a resumable game exists presents a system dialog with three actions: continue the saved game, start the configured new game, or cancel.
- Choosing to start the new game finalizes the saved game with its actual partial result, adds it to history and aggregate statistics, then starts the new configuration.
- A game that reaches its last card is added to history immediately, before the result screen is dismissed.
- Repeating difficult cards from the result screen starts a distinct game with a new session identifier.
- History is local, retained without an artificial item limit, and ordered newest first.
- Users cannot delete history entries in this version.
- A finalized partial game is presented like any other history entry. It has no special status label; its partial progress, such as “12 of 30”, communicates that not every card was completed.

## User Experience

### Leaving and resuming a game

While a game is active, its close button presents a confirmation with:

- **Save and Exit** — persists the current game and returns to the library;
- **Continue Game** — dismisses the confirmation and stays in the game.

The app does not offer a destructive discard action. Backgrounding or terminating the app also preserves the latest playable snapshot.

The existing automatic resume alert on app launch is removed. Resume becomes a calm, persistent entry point rather than an interruption.

### Library banner

When a resumable game exists, a compact accent-colored banner appears above the library's cards. It is a single accessible button and contains:

- the study mode;
- completed-card progress, “X of Y”;
- relative time of the latest activity;
- a clear **Continue** call to action.

The banner disappears as soon as the game is naturally completed or finalized into history. When no resumable game exists, it occupies no layout space.

### Starting another game

The conflict is checked after the user configures a new game and presses **Start**. This preserves the selected mode, direction, tags, and card set if the user chooses to replace the old game.

The system dialog offers:

- **Continue Saved Game** — opens the resumable game and ignores the newly configured selection;
- **Start New Game** — finalizes the resumable game, then starts the already configured game;
- **Cancel** — stays on setup without changing either game.

If finalizing the old game cannot be persisted, the old snapshot is retained, the new game is not started, and the user sees a recoverable error message.

### History navigation and list

A dedicated history button in the library toolbar opens a separate **History** screen.

The screen contains:

1. the resumable-game banner, when present;
2. all finalized games, newest first.

Each finalized-game row shows:

- completion date and time;
- study mode;
- progress, “X of Y”;
- first-try recall percentage.

Tapping a finalized game opens its read-only detail screen. When there are no finalized games and no resumable game, the screen presents an explanatory empty state.

### History details

The detail screen shows:

- start/completion date and time;
- mode;
- direction;
- selected tag names, or **All Cards** when no tag filter was used;
- duration;
- completed and planned card counts;
- repeated-card count;
- first-try recall percentage;
- saved display names of difficult cards.

The stored labels are immutable snapshots. Renaming or deleting vocabulary cards and tags later does not change an existing history entry.

All new controls and information support VoiceOver, Dynamic Type, sufficient accent-color contrast, minimum touch targets, and reduced-motion preferences where animation is used.

## Metrics

### Progress

**completedCardCount** is the number of unique cards removed from the session queue by a successful final assessment. **plannedCardCount** is the size of the configured card set when the game began.

History displays progress as “completedCardCount of plannedCardCount”. A naturally completed game therefore shows equal values. A game finalized early usually shows a smaller completed count.

### First-try recall

The denominator is the number of unique cards actually assessed at least once, not the planned card count. A card becomes encountered on the first remember/forget assessment in flashcard mode or the first answer check/answer reveal in writing mode. Merely displaying the next card before the user acts does not classify it as encountered. Unseen and unassessed cards do not lower the percentage when a game is finalized early.

An encountered card counts as recalled on the first try when it was never marked for repetition. The percentage is:

    (encounteredCardCount - repeatedEncounteredCardCount)
    / encounteredCardCount * 100

The value is zero when no card was encountered. For a naturally completed game, this definition matches the existing result-screen recall metric.

### Aggregate statistics

Naturally completed and finalized-early games both update aggregate statistics exactly once. A finalized-early game contributes only its actual completed cards, encountered cards, attempts, repeated cards, mistakes, and duration. Its unseen cards contribute nothing except to the planned count retained in its history record.

Active foreground study time continues to feed daily progress through the existing timer. Finalizing a game must not add that duration a second time.

## Domain Model

Extend the resumable **StudySessionSnapshot** with versioned fields needed for correct partial-game presentation and finalization:

- **sessionID**, preserved across every save and resume so history and aggregate-statistics deduplication use one stable identity;
- **lastActivityAt**;
- **encounteredCardIDs**;
- immutable session-start display metadata sufficient to finalize even after source objects change: selected tag names and a card-ID-to-display-title snapshot for every planned card.

Introduce a small Codable card-display snapshot value containing a card identifier and title. Bump the snapshot format to version 2. The store explicitly accepts version 1, derives safe defaults from the available library values, and returns a normalized version-2 snapshot; versions newer than the app supports remain invalid. This replaces the current exact-version rejection so existing resumable games survive the upgrade when their referenced cards are still available.

Introduce an immutable **StudyHistoryEntry** domain value with at least:

- **id** / session identifier;
- **startedAt**, **completedAt**;
- **mode**, **direction**;
- **selectedTagNames**;
- **plannedCardCount**, **completedCardCount**, **encounteredCardCount**;
- **repeatedCardCount**, **totalAssessmentCount**, and the mistake count used by aggregate statistics;
- **elapsedSeconds**;
- **difficultCardTitles**.

Derived presentation values such as progress text and recall percentage are computed from validated stored counts rather than persisted redundantly.

Extend **StudyResult** and aggregate statistics with distinct completed- and encountered-card counts. Existing completed-card totals and averages continue to use the completed count; first-try recall uses the encountered count. Decoding existing statistics defaults the encountered count to the former studied-card count, preserving current results.

## Persistence Architecture

Keep the existing single resumable snapshot in its lightweight **StudySessionStore**. Store finalized history as SwiftData records because the collection is unbounded and individually queryable.

Define a **StudyHistoryRepository** protocol in **Core** with operations to:

- fetch entries newest first;
- insert a finalized entry idempotently by session identifier.

Implement it in **Data** using a new SwiftData history entity included in the application schema. Small immutable collections such as tag names and difficult-card titles may be represented by Codable value arrays, provided round-trip tests cover them.

Add the history entity through an additive SwiftData schema version and lightweight migration plan that preserves the existing vocabulary entities and data. Existing UserDefaults statistics and daily-progress stores remain in place.

## Session Finalization

Use one finalization service or coordinator as the sole path for both natural completion and replacement of an unfinished game. It:

1. derives a validated history entry and aggregate **StudyResult** from the live session or saved snapshot;
2. inserts the history entry idempotently;
3. records aggregate statistics idempotently with the same session identifier;
4. clears the resumable snapshot only after the history insert succeeds;
5. exposes success or failure to navigation.

Natural completion invokes this flow as soon as the last card is assessed, while keeping the result screen on screen. Starting a replacement game invokes it from the setup conflict dialog and starts the pending configuration only after success.

If statistics persistence fails after the history insert, retrying remains safe because both repositories deduplicate by session identifier. The resumable snapshot remains until the coordinator has completed its required operations.

## Deleted or Changed Source Data

History never depends on live vocabulary or tag relationships.

For a resumable game, available queued cards remain playable after reload. Missing queued cards are skipped without changing the planned count. If no playable queued cards remain, the app finalizes the snapshot using its captured metadata and actual progress instead of silently discarding it.

## Components and Navigation

- Add a focused history feature module containing the list, details, presentation mapping, and reusable resumable banner.
- Add a history route to application navigation.
- Extend the root view model to expose the resumable presentation, load history, coordinate resume/finalization, and hold a pending new-game configuration while the conflict dialog is visible.
- Inject resume/history UI into the existing library screen without coupling the library's card-management view model to persistence.
- Use one banner component on both the library and history screens so wording and accessibility remain consistent.

The app container constructs and injects the history repository and finalization coordinator alongside the existing session and statistics stores.

## Failure Handling

- A malformed or unsupported resumable snapshot is cleared using the existing defensive behavior.
- A failed history load shows a retryable error state rather than an empty history.
- A failed finalization never clears the resumable game or starts its replacement.
- A duplicate completion callback is a no-op after the first successful insert/record.
- Invalid negative counts or durations are clamped at domain initialization boundaries.

## Testing

### Core tests

- full and partial progress derivation;
- recall calculation based only on encountered cards;
- zero-encountered-card behavior;
- immutable label snapshots;
- finalized-entry validation;
- finalization ordering and failure behavior with test doubles.

### Data tests

- SwiftData insert/fetch round trip;
- newest-first ordering;
- idempotent insertion by session identifier;
- unlimited multi-entry storage behavior;
- schema construction with the new entity;
- backward-compatible decoding of existing resumable snapshots.

### Feature and application tests

- both study modes update encountered-card and last-activity state;
- close confirms, persists, and returns to the library;
- launch presents a banner rather than an alert;
- tapping either banner resumes the correct mode and exact progress;
- starting a configured game presents the conflict dialog;
- continue, replace, and cancel branches;
- natural completion is recorded immediately and exactly once;
- finalized-early games contribute actual values to aggregate statistics;
- history empty, populated, partial-progress, and detail states;
- inaccessible or deleted queued cards follow the documented behavior.

### UI verification

Run the existing unit suite plus focused UI flows for library banner → resume, setup → replace old game, history → details, and both natural and early finalization. Verify VoiceOver labels, Dynamic Type layouts, touch targets, contrast, and reduced-motion behavior.

## Out of Scope

- deleting or editing history entries;
- cloud synchronization or backup of history;
- filtering, searching, or pagination controls for history;
- replaying a historical game from its detail screen;
- per-card answer timelines;
- visually labeling a finalized game as “completed early”.
