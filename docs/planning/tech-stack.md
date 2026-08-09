# CardFlipper Tech Stack

Last updated: 2026-08-09

| Area | Choice | Rationale |
| --- | --- | --- |
| Project generation | Tuist 4.40.0 | Reproducible modular Xcode project |
| Language | Swift 6.2 | Matches installed Xcode toolchain |
| UI | SwiftUI | Native declarative UI for iOS 18 |
| Observation | Observation framework | Modern testable ViewModel binding |
| Persistence | SwiftData | Native local persistence and relationships |
| Networking | URLSession | One small API with no need for a dependency |
| Speech | AVSpeechSynthesizer | Offline-capable system British pronunciation |
| Localization | String Catalog | Native Russian/English localization workflow |
| Testing | Swift Testing | Modern unit-test framework |
| Dependency injection | Initializer injection | Explicit and dependency-free |

## External Service

Free Dictionary API is used only for optional English IPA and parts-of-speech suggestions. The app remains usable when it is unavailable. No API key or authentication is stored.

## Build Configuration

- Debug and Release configurations.
- iOS 18 deployment target.
- iPhone device family only.
- Portrait orientation only.
- No third-party runtime packages.
- No network entitlement beyond standard HTTPS access.

## Not Included

- Backend, CloudKit, Firebase, or user authentication.
- Analytics and crash-reporting SDKs.
- CI/CD and automated signing.
- Lint or formatting dependency in the initial scaffold unless already available locally.
