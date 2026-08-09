# CardFlipper Roadmap

Last updated: 2026-08-09

## Phase 1: Project Foundation

- Create Tuist manifests and target graph.
- Add domain values and repository contracts.
- Configure localizations and shared visual primitives.
- Establish Swift Testing targets and fakes.

## Phase 2: Local Vocabulary

- Implement SwiftData schema and mappings.
- Implement card and tag repositories.
- Build library, search, filters, deletion, and empty states.
- Build editor, validation, duplicates, and tag creation.

## Phase 3: Language Assistance

- Implement debounced dictionary lookup with cancellation and timeout.
- Map the first available IPA and part of speech while keeping manual multi-selection.
- Add British system pronunciation.
- Cover success and failure paths with unit tests.

## Phase 4: Study

- Implement direction and tag selection.
- Implement injectable shuffling and queue transitions.
- Build accessible flip interaction, assessment controls, and haptics.
- Build exit confirmation and result/repeat flow.

## Phase 5: Verification and Polish

- Run all unit tests and build the generated project.
- Verify persistence across relaunches.
- Verify Russian/English, light/dark mode, Dynamic Type, VoiceOver, and Reduce Motion.
- Update README with generation, build, and test commands.

## Version 1 Completion

Version 1 is complete when all acceptance criteria in the canonical design specification pass and no deferred capability has leaked into the implementation scope.
