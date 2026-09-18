# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Operating Context

Card import is a staged review workflow: users inspect the complete import preview, may correct individual cards, and then confirm the import as a whole.

## Capabilities and Constraints

- Import Preview preserves the three-way grouping of cards: New, Changed, and Unchanged.
- Selecting a card in Import Preview opens the existing `CardEditorView` directly. There is no intermediate card-detail screen in this workflow.
- Changes made from Import Preview remain in the import draft. They do not modify the library until the user confirms the overall import.

## Product Principles

- Keep the full import outcome visible before committing it.
- Make corrections in the established card-editing experience.
- Treat import review as one transactional draft with an explicit final confirmation.
