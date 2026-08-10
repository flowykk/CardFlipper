# Library Translation Animation

## Goal

Make revealing and hiding Russian translations in the Library feel continuous without distracting from vocabulary content.

## Interaction

Changing the existing “Show translations” toggle animates all affected rows together. Russian content fades and moves a short distance from the top while each row smoothly adjusts its height. The transition lasts 0.2 seconds and does not animate unrelated search, filtering, editing, or deletion updates.

When Reduce Motion is enabled, Russian content uses opacity only, avoiding positional motion while preserving a clear visual state change.

## Architecture

`LibraryView` owns the transaction because its toggle changes every visible row. `VocabularyCardRow` owns the conditional-content transition because it renders the inserted or removed Russian block. No animation state is stored or persisted.

## Verification

The existing UI test continues to verify that Russian text is absent before the toggle and present afterward. A focused source-level unit is not warranted because transition execution belongs to SwiftUI; compilation, the full test suite, and the existing end-to-end behavior test protect integration.

## Scope

No changes to copy, toggle placement, data flow, filtering, persistence, or card content are included.
