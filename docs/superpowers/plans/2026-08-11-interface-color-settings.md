# Interface Color Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent settings screen that lets users choose the app-wide accent color with the native SwiftUI color picker.

**Architecture:** An app-owned observable `AppearanceSettings` stores validated opaque sRGB components in an injected `UserDefaults`. `RootView` owns the settings object, applies its color above the complete presentation hierarchy with `.tint`, and routes to an app-owned `SettingsView`.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation `UserDefaults`, Swift Testing, Tuist/Xcodebuild, iOS 18.

## Global Constraints

- Keep system blue as the default accent.
- Use only the native `ColorPicker`; do not add preset swatches or opacity selection.
- Apply changes immediately and persist them across launches.
- Store portable opaque sRGB components, not archived UIKit or SwiftUI color values.
- Keep settings in `CardFlipperApp`; feature modules must not depend on it.
- Localize new user-facing copy in English and Russian.
- Preserve semantic colors such as destructive red and study-session orange.

---

### Task 1: Persistent Appearance Settings

**Files:**
- Create: `Sources/CardFlipperApp/AppearanceSettings.swift`
- Modify: `Tests/CardFlipperAppTests/AppCompositionTests.swift`

**Interfaces:**
- Consumes: `UserDefaults`, SwiftUI `Color`, UIKit `UIColor` for reliable sRGB conversion.
- Produces: `@MainActor @Observable final class AppearanceSettings`, `init(defaults: UserDefaults = .standard)`, and mutable `var accentColor: Color`.

- [ ] **Step 1: Write failing persistence tests**

Add tests that create an isolated defaults suite, confirm the default converts to opaque system blue, assign `Color(.sRGB, red: 0.25, green: 0.5, blue: 0.75)`, recreate the store, and compare extracted sRGB components within `0.001`. Add invalid-value coverage by writing JSON containing an out-of-range or non-finite component under `AppearanceSettings.storageKey` and asserting fallback to blue.

```swift
@MainActor
@Test func appearanceSettingsPersistAndRestoreOpaqueSRGBColor() throws {
    let defaults = try #require(UserDefaults(suiteName: #function))
    defaults.removePersistentDomain(forName: #function)
    defer { defaults.removePersistentDomain(forName: #function) }

    let settings = AppearanceSettings(defaults: defaults)
    settings.accentColor = Color(.sRGB, red: 0.25, green: 0.5, blue: 0.75)

    let restored = AppearanceSettings(defaults: defaults)
    let components = try #require(restored.sRGBComponents)
    #expect(abs(components.red - 0.25) < 0.001)
    #expect(abs(components.green - 0.5) < 0.001)
    #expect(abs(components.blue - 0.75) < 0.001)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
tuist generate --no-open
xcodebuild test -workspace CardFlipper.xcworkspace -scheme CardFlipper -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:CardFlipperAppTests
```

Expected: compilation fails because `AppearanceSettings` does not exist.

- [ ] **Step 3: Implement the minimal validated settings store**

Create a focused file with a private `Codable` RGB value, validation for finite closed-range components, a system-blue default derived from `UIColor.systemBlue`, and write-through persistence from `accentColor`. Keep `storageKey` internal for `@testable` tests and expose an internal read-only `sRGBComponents` tuple for deterministic comparisons.

```swift
@MainActor
@Observable
final class AppearanceSettings {
    static let storageKey = "com.danilarahmanov.CardFlipper.appearance.accentColor"

    var accentColor: Color {
        didSet { persist(accentColor) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentColor = Self.restore(from: defaults) ?? Color(uiColor: .systemBlue)
    }
}
```

Conversion must request an sRGB `CGColorSpace`, reject failed conversion and invalid components, discard alpha on save, and always rebuild with alpha `1`.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the same `xcodebuild test ... -only-testing:CardFlipperAppTests` command. Expected: all app composition tests pass.

- [ ] **Step 5: Commit the settings store**

```bash
git add Sources/CardFlipperApp/AppearanceSettings.swift Tests/CardFlipperAppTests/AppCompositionTests.swift
git commit -m "feat: persist interface accent color"
```

### Task 2: Settings Screen and App-Wide Tint

**Files:**
- Create: `Sources/CardFlipperApp/SettingsView.swift`
- Modify: `Sources/CardFlipperApp/RootView.swift`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`
- Modify: `Tests/CardFlipperAppTests/AppCompositionTests.swift`

**Interfaces:**
- Consumes: `AppearanceSettings.accentColor`, `AppNavigationState.path`, `AppRoute`.
- Produces: `AppRoute.settings`, `AppNavigationState.openSettings()`, and `SettingsView(settings: AppearanceSettings)`.

- [ ] **Step 1: Write the failing navigation test**

```swift
@MainActor
@Test func openingSettingsAppendsTheSettingsRouteOnlyOnce() {
    let navigation = AppNavigationState()
    navigation.openSettings()
    navigation.openSettings()
    #expect(navigation.path == [.settings])
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run the app test target command from Task 1. Expected: compilation fails because the route and action do not exist.

- [ ] **Step 3: Add settings navigation and global ownership**

Add `.settings` to `AppRoute`, add an idempotent `openSettings()` method, store `AppearanceSettings` in `RootView` with an injectable default, and append the settings destination. Apply `.tint(settings.accentColor)` after the sheet and full-screen-cover modifiers so all presentations inherit the selected accent.

Update the library toolbar to contain both actions in one trailing `ToolbarItemGroup`: keep the existing statistics button and add a `gearshape` settings button calling `navigation.openSettings()`, with accessibility identifier `library.settings`.

- [ ] **Step 4: Implement the native settings form**

Create `SettingsView` with `@Bindable var settings: AppearanceSettings`, a localized navigation title, and a `Form` appearance section. Bind `ColorPicker("settings.interfaceColor", selection: $settings.accentColor, supportsOpacity: false)` and add a compact labeled preview using `Color.accentColor` plus a non-color-only text label and accessibility identifier `settings.colorPicker`.

- [ ] **Step 5: Add English and Russian localization entries**

Merge these keys into the existing String Catalog without replacing unrelated or currently modified entries:

```text
settings.open: Settings / Настройки
settings.title: Settings / Настройки
settings.appearance: Appearance / Оформление
settings.interfaceColor: Interface Color / Цвет интерфейса
settings.preview: Accent Color Preview / Предпросмотр цвета интерфейса
```

- [ ] **Step 6: Run focused tests and build**

```bash
xcodebuild test -workspace CardFlipper.xcworkspace -scheme CardFlipper -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:CardFlipperAppTests
xcodebuild build -workspace CardFlipper.xcworkspace -scheme CardFlipper -destination 'generic/platform=iOS Simulator'
```

Expected: tests and build succeed without warnings introduced by these files.

- [ ] **Step 7: Commit the settings UI**

```bash
git add Sources/CardFlipperApp/SettingsView.swift Sources/CardFlipperApp/RootView.swift Resources/CardFlipperApp/Localizable.xcstrings Tests/CardFlipperAppTests/AppCompositionTests.swift
git commit -m "feat: add interface color settings screen"
```

### Task 3: Visual and Regression Verification

**Files:**
- Modify only if verification reveals a defect in files from Tasks 1–2.

**Interfaces:**
- Consumes: the completed settings flow.
- Produces: verified navigation, live tint propagation, persistence, accessibility labels, and clean regression results.

- [ ] **Step 1: Run all non-UI unit tests**

```bash
xcodebuild test -workspace CardFlipper.xcworkspace -scheme CardFlipper -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -skip-testing:CardFlipperUITests
```

Expected: all unit test bundles pass.

- [ ] **Step 2: Launch and inspect in Simulator**

Build, boot an available iPhone simulator, install and launch the app. Verify the gear opens Settings, the picker has no opacity slider, changing the color immediately updates navigation controls and preview, semantic red/orange controls remain unchanged, and the chosen color survives app termination and relaunch.

- [ ] **Step 3: Run repository hygiene checks**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; pre-existing unrelated changes remain intact and unstaged.

- [ ] **Step 4: Commit any verification-only fixes**

If a defect was found, stage only files changed for this feature and commit:

```bash
git commit -m "fix: polish interface color settings"
```

If no defect was found, do not create an empty commit.
