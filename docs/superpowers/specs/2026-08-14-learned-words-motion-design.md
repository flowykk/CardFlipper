# Learned Words Motion

## Goal

Make the learned-word filter feel responsive without changing its filtering behavior.

## Layout

In the Library list, the learning-status segmented picker follows the horizontal tag filter. The translation toggle remains above both filters.

## Motion

Changing the learning-status picker animates the affected card rows with a snappy opacity and slight vertical move transition. The same transition is used when a swipe action changes a card’s learned state and causes it to leave the active filter.

When Reduce Motion is enabled, use a brief ease-in-out opacity transition instead of movement.

## Verification

The Library UI test verifies the selector remains available. The feature test suite and an app build verify the changed view compiles and filtering behavior is unchanged.
