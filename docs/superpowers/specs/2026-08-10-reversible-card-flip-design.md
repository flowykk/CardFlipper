# Reversible Study Card Flip Design

## Goal

Allow the learner to flip the current study card in both directions by tapping anywhere inside the card surface, including visually empty space.

## Behavior

- The card initially shows the configured prompt side.
- The first tap shows the answer and permanently unlocks the Remember and Don't remember actions for the current card.
- Every later tap toggles the visible side between prompt and answer.
- Assessment actions remain visible after the answer has been viewed, even when the prompt side is visible again.
- Moving to the next card resets both the visible side and the answer-viewed state.
- Speech is available only while the English side is visible.
- Reduce Motion continues to use the existing crossfade instead of 3D rotation.

## Architecture

`StudySession.isRevealed` remains the domain fact that the answer has been viewed and assessment is allowed. `StudySessionViewModel` owns a separate `isShowingAnswer` presentation state. The first flip reveals the domain session and shows the answer; subsequent flips only toggle presentation state. Assessment resets presentation state after Core advances the queue.

`StudyCardView` receives the visible-side state and a toggle callback. A full-size rectangular hit target covers the complete flashcard surface. Accessibility visibility and focus follow the currently visible face, while the answer-viewed domain state independently controls assessment actions.

## Feedback and Accessibility

- Flip haptic feedback occurs for each successful side toggle.
- The visible face alone is exposed to VoiceOver.
- Both faces expose the default accessibility action for toggling.
- The accessibility hint describes changing the visible side rather than a one-time reveal.

## Testing

- ViewModel test: first toggle unlocks assessment and shows the answer.
- ViewModel test: second toggle returns to the prompt without hiding assessment actions.
- ViewModel test: assessment advances the queue and resets the visible side.
- Presentation tests: rotations, opacity, accessibility visibility, and English speech follow `isShowingAnswer`.
- UI test: tapping an empty point inside the card toggles both directions and assessment actions remain present.

