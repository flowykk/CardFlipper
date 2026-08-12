# Daily Goal Wheel Picker

## Goal

Replace the daily-goal `Stepper` with a native iOS wheel picker presented in the existing sheet.

## Interaction

- Tapping `Edit Goal` presents the existing medium-height sheet.
- The sheet contains a `.wheel` picker covering every whole-minute value from 1 through 240.
- The current saved goal is selected when the sheet appears.
- Scrolling changes a local draft only; it does not persist the goal.
- Tapping `Done` saves the selected draft and closes the sheet.
- Dismissing the sheet interactively without tapping `Done` discards the draft.
- Reopening the sheet always starts from the currently persisted goal.

## UI and Accessibility

The selected number and localized minute unit are displayed by the system wheel picker. The navigation title remains localized through the `StatisticsFeature` resource bundle. The picker exposes a localized accessibility label and the selected minute value to VoiceOver.

## Architecture

`DailyGoalEditorView` owns the temporary draft using local SwiftUI state initialized from `ProgressDashboardViewModel.goalMinutes`. Only its confirmation action calls `model.setGoal(minutes:)`. No repository or persistence interfaces change.

## Testing

- Verify a draft begins with the persisted goal.
- Verify changing a draft does not update repository progress.
- Verify confirmation persists the draft.
- Verify a newly created draft after cancellation returns to the persisted goal.
- Run `StatisticsFeatureTests` and build `CardFlipper`.

## Out of Scope

- Preset buttons or recommended goal values.
- Changes to the 1–240 minute range.
- Changes to historical completion semantics.
- A custom horizontal carousel or animation system.
