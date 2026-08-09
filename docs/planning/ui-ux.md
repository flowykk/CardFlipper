# CardFlipper UI/UX

Last updated: 2026-08-09

## Navigation

```text
Library
├── Card editor (sheet)
├── Tag filter and management
└── Study setup
    └── Study session
        └── Result
```

The library is the root. `NavigationStack` handles linear destinations; card editing uses a sheet. The active study experience minimizes unrelated navigation.

## Main States

### Library

- Empty: explanation and “Add card.”
- Populated: searchable list, tag filter, add and study actions.
- Filtered empty: explain the active filter and allow clearing it.
- Load failure: concise error with retry.

### Editor

- Ordered Russian and English inputs.
- Per-English-variant IPA, parts of speech, lookup status, and speech action.
- Inline validation without discarding user input.
- Duplicate warning that permits confirmation.

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

### Result

- Unique cards and forgotten-tap count.
- Primary repeat action and secondary return action.

## Visual Language

- System typography and colors.
- System blue accent.
- SF Symbols.
- Rounded cards and restrained depth.
- Automatic light/dark modes.
- Short flip animation with Reduce Motion alternative.
- Light and semantically distinct haptics.

## Accessibility

- Dynamic Type without truncating card content.
- VoiceOver labels include language and state.
- Logical focus changes after flip and assessment.
- Minimum 44-point interactive targets.
- Meaning never depends on color alone.
- Russian and English strings are stored in a String Catalog.
