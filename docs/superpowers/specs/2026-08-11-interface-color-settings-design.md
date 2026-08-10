# Interface Color Settings Design

Date: 2026-08-11

## Goal

Add an app settings screen where the user can choose the interface accent color manually. The chosen color applies immediately throughout the app and remains selected after relaunch.

## User Experience

- Add a settings button with the `gearshape` SF Symbol to the library's top toolbar, alongside the existing statistics action.
- Tapping the button pushes a localized “Settings” screen onto the existing `NavigationStack`.
- The screen contains an “Appearance” section with a system `ColorPicker` labeled “Interface color.”
- The picker does not expose opacity controls.
- The section includes a compact preview that uses the selected accent color so the result is visible before leaving the screen.
- A color change takes effect immediately across the settings screen and the rest of the application.
- The initial value is the application's current system-blue accent.
- The selected color is saved automatically and restored on the next launch.

## Architecture

Create an app-owned appearance settings type responsible for:

- representing the accent color as portable RGB components rather than archiving a platform color object;
- validating and decoding persisted values;
- falling back to system blue if persisted data is absent or invalid;
- writing changes to an injected `UserDefaults` store.

The app composition root owns this observable settings instance. `RootView` reads its current color and applies it using SwiftUI's `.tint(...)` modifier above the navigation and presentation hierarchy. The settings screen receives the same instance, so edits update the entire UI immediately.

Settings navigation remains app-owned because it is launched from the root library toolbar and affects every feature. Add a `settings` case to `AppRoute`; no feature module needs to depend on the settings implementation.

## Components

### AppearanceSettings

An `@MainActor @Observable` reference type in `CardFlipperApp`:

- exposes a SwiftUI `Color` suitable for `.tint` and `ColorPicker` binding;
- persists red, green, and blue values under a namespaced preference key;
- accepts an injected `UserDefaults` instance for deterministic tests;
- uses an opaque sRGB representation.

### SettingsView

An app-target SwiftUI view containing a `Form` with one appearance section. It binds the system `ColorPicker` to `AppearanceSettings` and presents a simple accent-colored preview control. All user-facing strings live in the app String Catalog.

### Root Navigation

The library toolbar gains the settings action. The existing statistics action remains available. The `settings` route presents `SettingsView`, and the root view applies the selected tint so sheets and pushed screens inherit it.

## Data Flow

```text
ColorPicker edit
  -> AppearanceSettings updates RGB value
  -> AppearanceSettings writes UserDefaults
  -> observation invalidates RootView
  -> RootView applies the new global tint
```

On startup, `AppearanceSettings` reads the persisted RGB components. Missing, malformed, non-finite, or out-of-range values resolve to system blue.

## Accessibility and Localization

- Use the native `ColorPicker`, preserving system VoiceOver behavior and Dynamic Type support.
- Do not communicate selection through color alone: the control has the explicit “Interface color” label and the preview has a descriptive accessibility label.
- Keep the settings toolbar button at the system minimum hit target.
- Localize the settings title, section title, picker label, preview label, and toolbar accessibility text in Russian and English.

## Testing

- Unit-test the default blue value.
- Unit-test persistence and restoration of a custom RGB color.
- Unit-test fallback behavior for invalid persisted values.
- Test that the settings route can be opened through app navigation state.
- Build the application and run the relevant app test target.
- If a simulator is available, launch the app and visually verify navigation, the picker, immediate tint changes, and restoration after relaunch.

## Out of Scope

- A predefined color palette.
- Opacity selection.
- Light/dark appearance selection.
- Cloud synchronization of preferences.
- Custom coloring of destructive or semantic status actions.
