# CardFlipper Overview

Last updated: 2026-08-09

## Summary

CardFlipper is a private iPhone flashcard app for creating and reviewing Russian-English vocabulary. It targets daily personal use and deliberately favors a focused offline workflow over accounts, synchronization, or gamification.

## Key Decisions

- Platform: iPhone, portrait, iOS 18+
- UI: SwiftUI, Russian and English localization
- Architecture: feature-oriented Tuist modules with MVVM inside features
- Persistence: local SwiftData behind repository protocols
- Dictionary assistance: keyless Free Dictionary API for optional IPA and parts of speech
- Pronunciation: system `en-GB` speech synthesizer
- Study: user-selected direction, shuffled full filtered set, binary self-assessment
- Testing: Swift Testing unit suites for domain, data, services, and ViewModels

## Success Criteria

- Adding and locating a card is fast and understandable without onboarding.
- A study session can be started in either direction with no more than a few taps.
- Network failures never prevent manual card management or study.
- The library survives app relaunches.
- Module boundaries allow features and persistence to be tested independently.

## Main Risks

- Public dictionary availability: isolate it behind a protocol and keep manual entry fully functional.
- SwiftData relationship changes: isolate entities in `Data` and version the schema.
- Endless repeats for difficult cards: make remaining count and exit confirmation clear.

## Related Documents

- [Features](features.md)
- [Architecture](architecture.md)
- [Tech stack](tech-stack.md)
- [UI/UX](ui-ux.md)
- [Data model](data-model.md)
- [Roadmap](roadmap.md)
- [Canonical design specification](../superpowers/specs/2026-08-09-cardflipper-design.md)
