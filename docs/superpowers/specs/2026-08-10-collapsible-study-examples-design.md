# Collapsible Study Examples Design

## Goal

Move English usage examples out of the flashcard surface into an expandable section below the Remember and Don't remember actions. Keep the expanded section visible while the user flips either side of the same card.

## Interaction

- The flashcard itself contains only the prompt or answer content and its existing metadata, without usage examples.
- The examples control appears below the assessment actions after the answer has been revealed at least once.
- Cards without usage examples do not show the control.
- The collapsed control reads “Show examples” and indicates the number of available examples.
- Tapping it expands all examples for the current card; tapping again collapses them.
- Every row shows its part of speech, English sentence, and the existing speech action.
- Expanded state survives any number of front/back flips for the current card.
- Remember and Don't remember advance the queue and reset examples to collapsed for the next card, even when a forgotten card later returns.
- Starting or repeating a study session also starts collapsed.

## Architecture and Data Flow

`StudySessionViewModel` owns `isShowingUsageExamples`, because this presentation state must survive `StudyCardView` replacement during a flip but reset when the study queue advances. It exposes a guarded toggle that only changes state when assessment is unlocked and the current card has examples.

`StudyCardView` stops rendering usage examples. `StudySessionView` places a dedicated examples disclosure section after `assessmentActions` and passes sentence speech actions back to the existing view-model API. No persistence or Core model changes are required.

## Layout and Accessibility

The session remains vertically scrollable so expanded examples fit small screens and Dynamic Type. The disclosure button uses a chevron, an explicit expanded/collapsed accessibility value, and a stable identifier. Example speech controls retain their current identifiers and labels.

## Testing

- View-model tests cover the initial collapsed state, guarded expansion, persistence across flips, and reset after Remember/Don't remember.
- Presentation tests confirm usage examples are absent from the flashcard face.
- UI tests reveal a seeded card, expand examples below assessment actions, flip both directions, and confirm the expanded content remains visible.
- Run the complete Tuist test suite and a clean application build before completion.
