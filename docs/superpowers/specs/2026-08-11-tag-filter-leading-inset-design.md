# Tag Filter Leading Inset

## Goal

Align the first Library tag chip with the leading edge of the existing “Show translations” row instead of placing it against the screen edge.

## Design

The horizontal tag `ScrollView` receives a 20-point leading content margin. The margin applies to scroll content only, preserving the zero-inset list row, the chip sizes and spacing, the trailing tag-management menu position, and horizontal scrolling behavior.

## Verification

Build the `LibraryFeature` target and run the existing Library UI flow. No data, accessibility, localization, filtering, selection, or deletion behavior changes are included.
