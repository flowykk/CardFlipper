# Daily Goal Wheel Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the daily-goal stepper with a native wheel picker that saves only when the user taps Done.

**Architecture:** A focused `DailyGoalEditorModel` owns the temporary minute selection and an injected save closure. `DailyGoalEditorView` renders values `1...240` using `Picker` with `.wheel` style; interactive dismissal drops the editor model with no persistence call.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, Tuist, iOS 18+.

## Global Constraints

- Preserve the daily-goal range `1...240` whole minutes.
- Initialize the wheel from the currently persisted goal.
- Persist only from the Done action; interactive dismissal cancels the draft.
- Preserve unrelated uncommitted source and string-catalog changes.

---

### Task 1: Test and implement draft goal state

**Files:**
- Create: `Sources/StatisticsFeature/DailyGoalEditorModel.swift`
- Create: `Tests/StatisticsFeatureTests/DailyGoalEditorModelTests.swift`

**Interfaces:**
- Consumes: current `Int goalMinutes` and `@MainActor (Int) -> Void onSave`.
- Produces: `DailyGoalEditorModel.init(goalMinutes:onSave:)`, mutable `selectedMinutes`, range `minuteOptions`, and `confirm()`.

- [x] Write a failing test that initializes at 15, changes the draft to 30 without calling the save spy, then confirms and observes exactly one saved value of 30.
- [x] Write a failing test that a newly constructed editor after an unconfirmed draft initializes again from persisted value 15 and exposes `Array(1...240)`.
- [x] Run `tuist test StatisticsFeature --no-selective-testing` and confirm RED because `DailyGoalEditorModel` is missing.
- [x] Implement the smallest observable main-actor editor model satisfying those tests.
- [x] Run `tuist test StatisticsFeature --no-selective-testing` and confirm GREEN.

### Task 2: Replace the stepper with the native wheel

**Files:**
- Modify: `Sources/StatisticsFeature/DailyGoalEditorView.swift`
- Modify: `Resources/StatisticsFeature/Localizable.xcstrings`

**Interfaces:**
- Consumes: `DailyGoalEditorModel` from Task 1 and `ProgressDashboardViewModel.setGoal(minutes:)`.
- Produces: a `.wheel` picker whose Done button invokes `editorModel.confirm()` before dismissing.

- [x] Initialize local editor state from `model.goalMinutes` and inject a closure that calls `model.setGoal(minutes:)`.
- [x] Replace the `Form` and `Stepper` with a `Picker` over `editorModel.minuteOptions`, tag each row by its minute value, apply `.pickerStyle(.wheel)`, and bind to `selectedMinutes`.
- [x] Add or reuse feature-bundle localization for the visible minute unit and picker accessibility label without overwriting unrelated catalog changes.
- [x] Make Done call `confirm()` and then set `model.isGoalEditorPresented = false`; leave interactive dismissal without save behavior.
- [x] Run `tuist test StatisticsFeature --no-selective-testing`, `tuist build CardFlipper`, `jq empty Resources/StatisticsFeature/Localizable.xcstrings`, and `git diff --check`.
- [x] Stage only the goal-wheel source, tests, plan, and localization hunk; commit as `feat: use wheel picker for daily goal`.
