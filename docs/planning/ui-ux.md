# CardFlipper UI/UX

Last updated: 2026-09-11

## Navigation

```text
Library
├── Card editor (sheet)
├── Tag filter and management
├── Statistics
├── Settings
└── Study setup
    └── Study session
        └── Result
```

The library is the root. `NavigationStack` handles linear destinations; card editing uses a sheet. The active study experience minimizes unrelated navigation.

## Main States

### Library

- Empty: explanation, primary “Add Card,” and secondary “Import Cards.”
- Populated: searchable list, tag filter, add and study actions.
- Filtered empty: explain the active filter and allow clearing it.
- Load failure: concise error with retry.
- Learned state is written on the row and every change offers Undo; it is never color-only.

### Editor

- Ordered Russian and English inputs.
- Russian/English values are primary; IPA, part of speech, lookup status, and examples use progressive disclosure.
- Inline validation without discarding user input.
- Duplicate warning that permits confirmation.
- Unsaved edits require explicit confirmation before dismissing.

### Study setup

- Direction selector.
- Multi-select tag list.
- Matching-card count.
- Disabled start action when the match count is zero.

### Study

- Remaining count and fixed direction.
- Large tappable card.
- Assessment actions only after reveal.
- Confirmation before exit.
- An interrupted session is versioned and restored after relaunch; missing cards are removed safely.

### Result

- Reviewed cards, cards repeated, recall rate, duration, daily-goal progress, and difficult-card names.
- “Repeat Difficult” is contextual; “Done” always returns to the Library.

### Statistics

- A first-use state explains which feedback appears and offers “Start Studying.”
- Populated statistics include today’s goal, current/previous seven-day trend, streak, recall, and totals.
- Calendar days distinguish future, no activity, below goal, achieved, and today using shape plus text—not color alone.

## Visual Language

- System typography and colors.
- Curated adaptive accent palette. Every offered accent selects black or white action text by measured contrast in light and dark modes.
- Semantic SF Symbols are centralized: Library uses `rectangle.stack.fill`, Study uses `graduationcap.fill`, and Tags uses `tag`.
- Rounded cards and restrained depth.
- Automatic light/dark modes.
- Short flip animation with Reduce Motion alternative.
- Filtering never uses movement that resembles deletion or reordering.
- Light and semantically distinct haptics.

## Accessibility

- Dynamic Type without truncating card content.
- VoiceOver labels include language and state.
- Logical focus changes after flip and assessment.
- Minimum 44-point interactive targets.
- Meaning never depends on color alone.
- Russian and English strings are stored in a String Catalog.
- Controls describe the resulting action or revealed content; for example, “Show Russian meanings.”

### Adaptive control policy

- At accessibility Dynamic Type sizes, horizontal segmented controls and paired actions use a vertical alternative.
- Bottom primary actions use safe-area insets and remain visible when scrollable content grows.
- Persistent status UI such as the study timer must not intersect the content or primary actions.
- Horizontal carousels provide a grid or list alternative when their labels no longer fit.
- Regression coverage includes iPhone 16e and iPhone 17 Pro in light/dark, English/Russian, standard text and Accessibility XXXL.

### Motion and state feedback

- Card flip preserves front/back geometry; Reduce Motion changes the flip to a crossfade.
- App-icon selection shows an in-place pending spinner, a persistent selected checkmark, and adjacent failure copy.
- Import/export alerts report exact added, merged, or exported card counts; failures never claim success.
- Reversible state changes expose Undo without hiding the updated state.
