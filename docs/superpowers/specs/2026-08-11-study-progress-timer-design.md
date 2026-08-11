# Study Progress Timer and Activity Calendar Design

**Date:** 2026-08-11
**Status:** Approved for implementation planning

## Summary

CardFlipper will track time spent actively reviewing cards. A study timer starts automatically when an active card-review screen appears, pauses whenever the app is no longer active, and resumes automatically when the user returns to the same study session. Completed time accumulates across study sessions into a local daily total.

The statistics screen will show today's progress, an editable daily goal, and a monthly activity calendar. A day becomes active after its goal is reached and never loses that status. A Live Activity will preserve and display the last fixed timer values while the app is inactive.

The feature remains local-first. It requires no account, server, push updates, analytics, or cloud synchronization.

## Product Rules

### Counted time

- Time counts only while the card-review portion of a study session is visible and the app scene is active.
- The timer starts automatically when card review begins. It has no manual start, pause, or resume controls.
- The timer pauses when the scene becomes inactive or enters the background.
- The timer resumes automatically when the scene becomes active and the same card-review session still exists.
- Time does not count on the study result screen, library, editor, setup, settings, or statistics screens.
- Finishing or abandoning a study session commits all elapsed time before dismissing the session.
- Repeating a completed study starts a new timer session and continues the same daily total.
- Multiple study sessions on the same local calendar day are summed.

### Daily goal

- The default daily goal is 15 minutes.
- The goal editor accepts 1 through 240 minutes.
- Changing the goal updates the preferred goal for future days and the current day's goal.
- Historical days are never recalculated when the preferred goal changes.
- Once a day's goal has been reached, its `goalAchieved` value remains true even if the user later increases the current day's goal.
- The timer continues after the goal is reached so the app preserves actual study time.

### Day boundaries

- Days use the device's local calendar and time zone at the time an interval is recorded.
- An active interval crossing midnight is split at the local start of the new day.
- The daily total resets for the new day.
- The current study-session duration continues across midnight.
- Previously stored records are not moved between dates after a time-zone change.
- Negative intervals caused by a backward wall-clock adjustment contribute zero time.

## User Interface

### Study timer

The active card-review screen shows a compact timer pill centered at the bottom through a safe-area inset. It must not cover the card or assessment buttons and is removed as soon as the result screen appears.

The visible format is:

```text
12:40 / +03:10
```

- The left value is today's accumulated study time, including the current session.
- The right value is the current study session's accumulated time.
- Digits use a monospaced design to prevent layout movement as values change.
- The pill uses system materials, system colors, and an SF Symbol timer icon.
- VoiceOver exposes the two values separately, for example: “Today, 12 minutes 40 seconds. Current session, 3 minutes 10 seconds.”

### Statistics screen

The existing statistics screen becomes a vertically ordered dashboard:

1. A Today card with accumulated time, the current goal, a system progress indicator, and an action to edit the goal.
2. A monthly activity calendar.
3. The existing lesson and card statistic tiles.

The goal action presents a small sheet containing a system `Stepper` with a range of 1 through 240 minutes. The initial value for a new installation is 15 minutes.

The calendar uses a system-styled seven-column grid and the user's calendar first-weekday setting. Completed days use a filled circle with a checkmark. Today also has a distinct outline. Month arrows navigate through historical months; navigation into a future month is disabled. Days without an achieved goal remain unmarked.

Calendar markings never rely on color alone. Each marked date has an accessible label that includes the date and completed status.

## Architecture

### Module ownership

`StatisticsFeature` owns the progress domain values, persistence contract and implementation, calendar presentation data, goal UI, timer presentation, and ActivityKit abstraction. The feature continues to expose public views and values to the app composition root.

`CardFlipperApp` owns orchestration because it already controls study presentation and scene lifecycle. It starts and stops the timer around `StudySessionView`, observes `scenePhase`, places the timer pill around the study content, and connects the repository and Live Activity client.

`StudyFeature` remains unaware of persistence and ActivityKit. Its existing completion and exit callbacks are used as lifecycle boundaries. If implementation needs a precise transition between active cards and results, it may add a narrow callback without importing another feature module.

The Live Activity UI is built in a new widget extension target. The app and extension share the `ActivityAttributes` type through `StatisticsFeature`, avoiding duplicated timer rules in the widget.

### Components

#### `DailyProgress`

A sendable value representing one local day:

- `day`: stable local-day identifier
- `elapsedSeconds`: nonnegative accumulated duration
- `goalSeconds`: the goal effective for that day
- `goalAchieved`: irreversible completion flag

#### `DailyProgressRepository`

A main-actor contract that provides:

- the preferred daily goal;
- lookup and month-range access to daily progress;
- interval accumulation split by local day boundaries;
- current-goal updates;
- persisted completion-state updates.

The first implementation is `UserDefaultsDailyProgressRepository`. It uses a versioned storage key separate from completed-study statistics. Empty days do not require records.

#### `StudyTimerController`

An observable, main-actor controller with one active study session at most. It owns:

- the current session identifier;
- accumulated session duration;
- the current active-segment anchor;
- derived current-day and current-session display values;
- lifecycle methods for start, scene activation, scene deactivation, completion, and abandonment;
- minute checkpoints and midnight rollover;
- coordination with `DailyProgressRepository` and the Live Activity client.

Elapsed time is derived from time anchors rather than incrementing a stored integer every second. A lightweight UI refresh updates the display, while durable writes occur only at lifecycle boundaries, midnight, and minute checkpoints.

#### `StudyTimerLiveActivityClient`

An injected main-actor abstraction with start, update, and end operations. The ActivityKit implementation checks system authorization and treats all failures as nonfatal. Tests use a fake client.

#### Calendar presentation

A small presentation layer converts stored daily records into month cells, leading placeholders, and navigation availability. Calendar arithmetic is isolated from the SwiftUI view and accepts an injected `Calendar` for deterministic tests.

## Data Flow

### Starting study

1. `CardFlipperApp` presents a fresh active study session.
2. The timer controller loads today's aggregate and starts a new session with zero session duration.
3. If the scene is active, the controller starts an active time segment immediately.
4. The app requests a Live Activity if the system permits it.
5. The study timer pill renders derived daily and session values.

### Leaving the app

1. The scene changes from active to inactive or background.
2. The controller closes the active segment at the transition time.
3. The repository splits and saves the interval by local calendar day.
4. The controller updates its current-session total.
5. The Live Activity receives the fixed daily and session values and a paused status.

The persistence step occurs before the ActivityKit update so a Live Activity failure cannot lose study time.

### Returning to study

1. The scene becomes active.
2. If card review is still the current presentation, the controller starts a new active segment automatically.
3. The Live Activity changes to a running status.
4. No background duration is added.

### Completing or abandoning study

1. The controller closes and persists any active segment.
2. The Live Activity ends immediately.
3. The timer pill disappears before or with the transition to the result or library.
4. The persisted daily total remains available to the statistics screen.

### Midnight rollover

When the date changes during an active session, the controller closes the old-day segment at midnight, persists it, begins the new day's record with the then-current preferred goal, and immediately starts a new active segment. The session duration is not reset.

## Live Activity

The app adds `NSSupportsLiveActivities` and a widget extension containing an `ActivityConfiguration`.

The content state contains compact, codable values only:

- fixed daily elapsed seconds;
- fixed current-session elapsed seconds;
- running or paused presentation status;
- last update date.

When the app is inactive, the Lock Screen presentation shows the app name, “Paused,” and the fixed `daily / +session` values. The Dynamic Island compact presentation shows a timer symbol and the fixed daily value. Its expanded presentation shows both values and the status. The minimal presentation uses the timer symbol.

There are no Live Activity buttons or toggles because timer control is automatic. Tapping the activity opens CardFlipper normally. The app ends all orphaned timer activities during cold-start cleanup before a new study activity is created.

The app does not depend on remote push updates or frequent ActivityKit updates. The in-app timer is authoritative while the app is active; ActivityKit receives lifecycle-boundary snapshots.

Apple documents that Live Activities require a widget extension and are started, updated, and ended through ActivityKit. Apple also recommends pausing work when a SwiftUI scene is inactive. These constraints align with the lifecycle above:

- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [SwiftUI ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase)

## Persistence Format

The repository stores a codable versioned payload under a new key such as `statistics.dailyStudyProgress.v1`:

```text
preferredGoalSeconds
recordsByLocalDay
  localDay
  elapsedSeconds
  goalSeconds
  goalAchieved
```

Durations are stored as nonnegative whole seconds. The local-day identifier is encoded independently of locale-specific date formatting. Decoding validates ranges. A malformed payload falls back safely to the default 15-minute goal and an empty progress history rather than crashing the application.

## Failure Handling

- Live Activities disabled: skip creation; timer and persistence remain fully functional.
- ActivityKit request, update, or end failure: ignore after preserving progress; retry only at the next natural lifecycle boundary.
- Corrupt progress payload: use safe defaults and allow a new valid payload to replace it on the next write.
- Backward clock movement: clamp elapsed contribution to zero.
- App termination after entering the background: the transition has already persisted the segment and published a fixed Live Activity snapshot.
- Stale activity left after system termination: end it during the next cold launch or before starting another study activity.

## Testing

### Repository tests

- Default goal is 15 minutes.
- Multiple intervals and sessions accumulate for the same day.
- Intervals crossing midnight split correctly.
- Goal completion becomes true at the threshold and never returns to false.
- Increasing an incomplete current-day goal changes its threshold.
- Increasing an achieved current-day goal preserves completion.
- Historical goals and completion do not change with the preferred goal.
- Persistence round-trips and corrupt payloads fall back safely.

### Timer controller tests

- Starting active study begins timing automatically.
- Inactive and background phases stop timing.
- Returning active resumes without counting the inactive interval.
- Completion and abandonment persist the last segment and end the activity.
- Repeated study starts a new session timer while retaining the daily total.
- Midnight resets the daily display but not the session display.
- Minute checkpoints do not double-count time.
- Backward clock changes do not add negative time.
- Display formatting produces `12:40 / +03:10`.

### Live Activity client tests

- Start, paused update, resumed update, and end occur at the expected boundaries.
- Disabled authorization skips creation.
- Request and update failures do not affect repository calls.
- Cold-start cleanup ends orphaned study timer activities.

### Calendar and UI tests

- Month grids handle different month lengths, leap years, and calendar first weekdays.
- Future-month navigation is disabled.
- Only achieved days receive completed styling and accessible completion labels.
- The timer pill appears only while cards are actively being reviewed.
- The timer pill disappears on result and abandonment.
- Goal edits update today's dashboard without changing historical records.

### App composition tests

- `AppContainer` provides one shared progress repository and timer controller dependency graph.
- Study presentation lifecycle events reach the controller exactly once.
- Existing completed-study statistics continue to record once per study result.

## Out of Scope

- Accounts, cloud sync, and cross-device progress.
- Server-driven or ActivityKit push updates.
- Manual timer controls or Live Activity buttons.
- Per-card or per-tag time analytics.
- A detailed persisted log of individual study sessions.
- Streak counters, achievements, reminders, and notifications.
- Editing historical daily records.
