# CardFlipper Design Specification

Date: 2026-08-09
Status: Approved

## Product Goal

CardFlipper is a private, everyday iPhone app for studying English vocabulary for general, professional, exam, interview, book, and film contexts. The user creates bilingual flashcards, selects a study direction, reveals the answer, and self-assesses with “Remember” or “Don’t remember.”

The first version is intentionally local-first and single-user. It has no account, cloud sync, analytics, monetization, import/export, onboarding, or persisted study history.

## Supported Platform

- App and Tuist project name: `CardFlipper`
- Bundle identifier: `com.danilarahmanov.CardFlipper`
- iPhone only
- Portrait orientation only
- Minimum deployment target: iOS 18
- SwiftUI and Swift 6.2
- Tuist 4.40.0
- Russian and English UI localizations selected from the device language
- Automatic light and dark appearances

## Vocabulary Model

A card contains:

- One or more Russian words or short phrases.
- One or more English words or short phrases.
- For every English variant, an optional IPA transcription.
- For every English variant, zero or more parts of speech from a fixed list such as `noun`, `verb`, `adj`, and `adv`.
- Zero or more user-defined tags.
- Creation and modification timestamps.

Only one Russian and one English value are required. Transcription and parts of speech remain optional so network or dictionary failures never block card creation.

The app warns about a possible duplicate after case-insensitive, whitespace-normalized comparison. The user may save it anyway.

## Library

The library is the initial screen and contains:

- A native list of all cards.
- Search across Russian meanings and English variants.
- Tag filtering.
- Card creation and editing.
- Swipe-to-delete with confirmation.
- Entry into study setup.

The empty state contains explanatory copy and a primary action to create the first card. The app ships without sample cards.

Tags can be created while editing a card. A card can have any number of tags. Deleting a tag requires confirmation and removes only its association; cards are preserved.

## Card Editing and Dictionary Lookup

The editor supports ordered lists of Russian meanings and English variants. Each English variant owns its transcription and parts of speech.

The user enters translations manually. The app queries Free Dictionary API only to suggest IPA and a part of speech. It accepts the first non-empty IPA value and the first available part of speech from the first dictionary entry. The suggested values remain editable, and the user may add other parts of speech manually.

Lookup behavior:

- Debounce requests after English text changes.
- Cancel obsolete requests.
- Use a finite timeout.
- Treat offline, timeout, decoding, and not-found results as non-blocking states.
- Never require an API key or store credentials.
- Preserve all form input after lookup or save errors.

English pronunciation uses the system speech synthesizer with the `en-GB` voice. The app does not download or persist audio.

## Study Setup

Before a session the user chooses exactly one direction:

- Russian to English.
- English to Russian.

The direction remains fixed throughout the session. The user may select multiple tags. Selected tags use OR semantics: a card is included if it has at least one selected tag. With no selected tags, the full library is used.

All matching cards are included and shuffled once at session start. There is no daily limit or spaced-repetition schedule.

## Study Session

The front displays the selected source language. For English-to-Russian sessions, the English front also displays IPA and parts of speech. The reverse displays every accepted value from the target side.

Tapping anywhere on the card performs a flip animation. Assessment actions are unavailable until the answer is revealed:

- “Remember” removes the card from the current queue.
- “Don’t remember” increments the error count and appends the card to the end of the queue.

The session ends only when every card has eventually received “Remember.” It displays the fixed direction, remaining-card count, pronunciation action where relevant, and an exit action. Exiting requires confirmation and discards the in-memory session.

## Session Result

The result displays:

- Number of unique cards in the session.
- Total number of “Don’t remember” taps.

The user may return to the library or repeat a freshly shuffled session with the same filters and direction. Results and history are not persisted.

## Navigation and Visual Design

The app uses `NavigationStack`; a tab bar is unnecessary for the small hierarchy. Card editing is presented as a sheet, study setup as a pushed destination, and the active session as a focused full-screen experience.

The interface uses system colors, SF Symbols, Dynamic Type, standard controls, and minimum 44-point hit targets. System blue is the primary accent. Success and failure colors are reinforced with text and symbols rather than color alone.

The card uses large typography, rounded corners, restrained shadow, and a short 3D flip. Reduce Motion replaces the flip with a simple transition. Light haptics occur on flip, and distinct haptics accompany both assessment actions.

VoiceOver identifies the current language, visible values, IPA, parts of speech, card side, and available action. Focus moves to the revealed answer after a flip and to the next card after assessment.

## Modular Architecture

The Tuist graph uses feature-oriented static frameworks:

```text
CardFlipperApp
├── LibraryFeature
├── CardEditorFeature
├── StudyFeature
├── Data
└── DesignSystem

LibraryFeature ────┐
CardEditorFeature ─┼──> Core
StudyFeature ──────┤
Data ──────────────┘
```

Responsibilities:

- `CardFlipperApp`: application entry point, navigation composition, and dependency construction.
- `Core`: domain value types, repository and service protocols, validation, normalization, and shared errors.
- `Data`: SwiftData entities, model mapping, local repositories, schema/migration setup, and dictionary client.
- `DesignSystem`: reusable visual primitives and accessibility-aware styling.
- `LibraryFeature`: list, search, filtering, tag management, and deletion.
- `CardEditorFeature`: creation, editing, validation, duplicate warning, lookup, and pronunciation.
- `StudyFeature`: setup, queue engine, card presentation, assessment, exit confirmation, and results.

Each feature owns SwiftUI views and `@MainActor @Observable` ViewModels. Feature modules depend on `Core` contracts and do not import SwiftData. Dependencies are composed manually in the app target and passed primarily through initializers.

## Persistence Model

SwiftData stores:

- `CardEntity`: identifier, timestamps, ordered relationships to meanings and variants, and tags.
- `RussianMeaningEntity`: identifier, text, sort index, and owning card.
- `EnglishVariantEntity`: identifier, text, optional IPA, parts-of-speech values, sort index, and owning card.
- `TagEntity`: identifier, unique display name, normalized name, and many-to-many card relationship.

Repositories map persistence entities to domain values so persistence does not leak into presentation code. Search and duplicate matching use normalized derived text while preserving the user’s original spelling for display.

Study queues, counters, selected filters, and results are transient and are never written to SwiftData.

## Error Handling

- Persistence loading failures show a retry state.
- Save failures keep the editor open and preserve input.
- Dictionary failures show a non-blocking message and leave manual fields available.
- Empty study selections explain that no cards match and return to setup.
- Destructive actions require explicit confirmation.
- Exiting an active session confirms that temporary progress will be lost.

## Testing

Unit tests use Swift Testing and cover:

- Validation and normalization.
- Search across both languages.
- OR tag filtering.
- Duplicate detection.
- Queue creation and shuffling through an injectable randomizer.
- “Remember,” “Don’t remember,” completion, and counters.
- SwiftData repository CRUD and relationships using an in-memory container.
- Dictionary success, empty, timeout, cancellation, and decoding failures.
- ViewModel state transitions with repository and service fakes.

UI tests, snapshot tests, CI, analytics, and crash reporting are outside the first-version scope.

## Acceptance Criteria

The design is complete when the generated project builds and tests successfully, and a user can:

1. Launch into an empty localized library.
2. Create tags and a card with multiple values on both sides.
3. Receive editable dictionary suggestions without making them mandatory.
4. Search, filter, edit, and delete stored cards.
5. Start either study direction for all cards or selected tags.
6. Flip cards and finish the queue using the required repeat behavior.
7. See the result and repeat the same selection.
8. Relaunch and find the locally stored library intact.

## Explicitly Deferred

- Accounts, backend, CloudKit, and multi-device sync.
- Import, export, and backup.
- Automatic translation.
- Spaced repetition and daily limits.
- Persisted statistics, streaks, and charts.
- Written or voice answer checking.
- Sample content and onboarding.
- iPad, landscape, macOS, and watchOS support.
- App Store release automation and monetization.
