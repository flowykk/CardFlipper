# CardFlipper Architecture

Last updated: 2026-08-09

## Pattern

The project uses feature-oriented modularization. Each feature applies MVVM locally; domain contracts and persistence implementations remain separate.

## Targets

| Target | Kind | Responsibility |
| --- | --- | --- |
| `CardFlipperApp` | iOS application | Entry point, navigation, dependency composition |
| `Core` | Static framework | Domain models, protocols, validation, normalization |
| `Data` | Static framework | SwiftData, repositories, dictionary transport and mapping |
| `DesignSystem` | Static framework | Shared visual components and tokens |
| `LibraryFeature` | Static framework | Library, search, filters, tags, deletion |
| `CardEditorFeature` | Static framework | Create/edit form, lookup, duplicates, speech |
| `StudyFeature` | Static framework | Setup, queue engine, card flow, results |

Test bundles accompany targets that contain business logic.

## Dependency Rules

- Feature targets may depend on `Core` and `DesignSystem`.
- `Data` depends on `Core` and never on a feature.
- `Core` has no dependency on UI or persistence frameworks.
- Only `Data` imports SwiftData.
- `CardFlipperApp` is the composition root and may import all production modules.
- Navigation data crossing feature boundaries uses `Core` values or app-owned routing types.

## State and Data Flow

```text
User action -> SwiftUI View -> Feature ViewModel -> Core protocol
            -> Data implementation -> SwiftData/API
            -> Domain value/result -> ViewModel state -> View
```

ViewModels are `@MainActor @Observable` reference types. Repository and service dependencies arrive through initializers. SwiftUI Environment is reserved for narrow UI concerns rather than service location.

## Alternatives Rejected

- Layer-only modularization: makes feature ownership and independent testing less clear.
- TCA: unnecessary dependency and conceptual weight for the state complexity.
- Micro-modules for every service or screen: excessive graph and maintenance overhead for a personal app.
- Direct SwiftData access from features: couples UI to persistence and complicates isolated tests.
