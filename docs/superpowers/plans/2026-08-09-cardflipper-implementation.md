# CardFlipper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved modular Tuist iPhone app for creating, filtering, pronouncing, and studying Russian-English flashcards.

**Architecture:** Tuist generates one iOS application, six static frameworks, and focused Swift Testing bundles. Feature modules use SwiftUI with `@MainActor @Observable` ViewModels, depend on domain protocols in `Core`, and receive concrete SwiftData and service implementations from the app composition root.

**Tech Stack:** Tuist 4.40.0, Swift 6.2, SwiftUI, Observation, SwiftData, URLSession, AVFoundation, String Catalogs, Swift Testing, iOS 18+

## Global Constraints

- Product name is `CardFlipper`; bundle identifier is `com.danilarahmanov.CardFlipper`.
- Support iPhone and portrait orientation only, with minimum deployment target iOS 18.
- Use Russian and English localizations selected from the device language.
- Keep all vocabulary local in SwiftData; do not add accounts, sync, analytics, import/export, or persisted study history.
- Do not add third-party runtime dependencies or API keys.
- Use Free Dictionary API only for optional IPA and first-part-of-speech suggestions.
- Use the system `en-GB` speech voice; do not download or persist audio.
- Feature modules must not import SwiftData.
- Use Swift Testing for unit tests and follow red-green-refactor for every behavior.
- Keep types and files focused; do not combine unrelated ViewModels, repositories, or screens.

## Planned File Structure

```text
CardFlipper/
├── Tuist.swift
├── Project.swift
├── Tuist/ProjectDescriptionHelpers/
│   └── TargetFactory.swift
├── Sources/
│   ├── CardFlipperApp/
│   │   ├── CardFlipperApp.swift
│   │   ├── AppContainer.swift
│   │   └── RootView.swift
│   ├── Core/
│   │   ├── Models/{VocabularyCard,CardDraft,Tag,PartOfSpeech}.swift
│   │   ├── Study/{StudyDirection,StudySession,CardShuffler}.swift
│   │   ├── Repositories/{CardRepository,TagRepository}.swift
│   │   ├── Services/{DictionaryService,SpeechService}.swift
│   │   └── Validation/TextNormalizer.swift
│   ├── Data/
│   │   ├── Persistence/{CardFlipperSchema,ModelContainerFactory}.swift
│   │   ├── Persistence/Entities/{CardEntity,RussianMeaningEntity,EnglishVariantEntity,TagEntity}.swift
│   │   ├── Persistence/Mapping/VocabularyCardMapper.swift
│   │   ├── Repositories/{SwiftDataCardRepository,SwiftDataTagRepository}.swift
│   │   └── Services/{FreeDictionaryClient,DictionaryDTO,SystemSpeechService}.swift
│   ├── DesignSystem/
│   │   ├── FlashcardSurface.swift
│   │   ├── PrimaryActionButton.swift
│   │   └── FeedbackGenerator.swift
│   ├── LibraryFeature/
│   │   ├── LibraryViewModel.swift
│   │   ├── LibraryView.swift
│   │   ├── VocabularyCardRow.swift
│   │   └── TagFilterView.swift
│   ├── CardEditorFeature/
│   │   ├── CardEditorViewModel.swift
│   │   ├── CardEditorView.swift
│   │   ├── RussianMeaningsSection.swift
│   │   ├── EnglishVariantsSection.swift
│   │   └── TagPickerSection.swift
│   └── StudyFeature/
│       ├── StudySetupViewModel.swift
│       ├── StudySetupView.swift
│       ├── StudySessionViewModel.swift
│       ├── StudySessionView.swift
│       ├── StudyCardView.swift
│       └── StudyResultView.swift
├── Resources/CardFlipperApp/
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/Contents.json
│   │   └── AccentColor.colorset/Contents.json
│   └── Localizable.xcstrings
├── Tests/
│   ├── CoreTests/{CardDraftTests,TextNormalizerTests,StudySessionTests}.swift
│   ├── CoreTests/TestFixtures.swift
│   ├── DataTests/{SwiftDataRepositoriesTests,FreeDictionaryClientTests,TestSupport}.swift
│   ├── LibraryFeatureTests/{LibraryViewModelTests,TestSupport}.swift
│   ├── CardEditorFeatureTests/{CardEditorViewModelTests,TestSupport}.swift
│   └── StudyFeatureTests/{StudySetupViewModelTests,StudySessionViewModelTests,TestSupport}.swift
└── README.md
```

---

### Task 1: Tuist Graph and Core Vocabulary Domain

**Files:**
- Create: `Tuist.swift`
- Create: `Project.swift`
- Create: `Tuist/ProjectDescriptionHelpers/TargetFactory.swift`
- Create: `Sources/CardFlipperApp/CardFlipperApp.swift`
- Create: `Sources/Core/Models/VocabularyCard.swift`
- Create: `Sources/Core/Models/CardDraft.swift`
- Create: `Sources/Core/Models/Tag.swift`
- Create: `Sources/Core/Models/PartOfSpeech.swift`
- Create: `Sources/Core/Repositories/CardRepository.swift`
- Create: `Sources/Core/Repositories/TagRepository.swift`
- Create: `Sources/Core/Validation/TextNormalizer.swift`
- Create: `Tests/CoreTests/CardDraftTests.swift`
- Create: `Tests/CoreTests/TextNormalizerTests.swift`
- Create: `Tests/CoreTests/TestFixtures.swift`

**Interfaces:**
- Produces: `VocabularyCard`, `RussianMeaning`, `EnglishVariant`, `Tag`, `PartOfSpeech`, `CardDraft`, `EnglishVariantDraft`, `CardRepository`, `TagRepository`, and `TextNormalizer`.
- Produces project targets: `CardFlipper`, `Core`, `Data`, `DesignSystem`, `LibraryFeature`, `CardEditorFeature`, `StudyFeature`, and their test bundles.

- [ ] **Step 1: Define the Tuist target factory and complete target graph**

Create a `TargetFactory` that produces iOS 18 static frameworks, test bundles, and the app target. In `Project.swift`, declare the dependency rules exactly as approved: every feature depends on `Core` and `DesignSystem`, `Data` depends on `Core`, and the app depends on all production modules. Configure `TARGETED_DEVICE_FAMILY = 1`, `UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`, Debug/Release, Swift 6, and app resources.

```swift
import ProjectDescription

let project = Project(
    name: "CardFlipper",
    targets: [
        .framework(name: "Core"),
        .framework(name: "Data", dependencies: [.target(name: "Core")]),
        .framework(name: "DesignSystem"),
        .framework(name: "LibraryFeature", dependencies: [.target(name: "Core"), .target(name: "DesignSystem")]),
        .framework(name: "CardEditorFeature", dependencies: [.target(name: "Core"), .target(name: "DesignSystem")]),
        .framework(name: "StudyFeature", dependencies: [.target(name: "Core"), .target(name: "DesignSystem")]),
        .app(
            name: "CardFlipper",
            bundleId: "com.danilarahmanov.CardFlipper",
            dependencies: ["Core", "Data", "DesignSystem", "LibraryFeature", "CardEditorFeature", "StudyFeature"]
        ),
        .tests(name: "CoreTests", host: "Core")
    ]
)
```

- [ ] **Step 2: Add failing normalization and draft-validation tests**

```swift
import Testing
@testable import Core

@Test func normalizationCollapsesWhitespaceAndCase() {
    #expect(TextNormalizer.searchKey("  Hello   WORLD ") == "hello world")
}

@Test func draftRequiresOneValueOnBothSides() {
    let draft = CardDraft(russianMeanings: ["слово"], englishVariants: [], tagIDs: [])
    #expect(draft.validationErrors == [.missingEnglishVariant])
}

@Test func blankItemsAreRemovedFromValidatedDraft() throws {
    let draft = CardDraft(
        russianMeanings: [" слово ", "  "],
        englishVariants: [.init(text: " word ", ipa: nil, partsOfSpeech: [])],
        tagIDs: []
    )
    let card = try draft.makeCard(id: UUID(), now: Date(timeIntervalSince1970: 1))
    #expect(card.russianMeanings.map(\.text) == ["слово"])
    #expect(card.englishVariants.map(\.text) == ["word"])
}
```

- [ ] **Step 3: Generate and run tests to confirm the missing-type failures**

Run: `tuist generate --no-open && tuist test CardFlipper --no-selective-testing`

Expected: compilation fails because `TextNormalizer`, `CardDraft`, and the domain types are not defined.

- [ ] **Step 4: Implement the minimal domain model and contracts**

Use immutable `Sendable`, `Equatable`, `Identifiable` value types. Keep `CardDraft` mutable-friendly but make `makeCard(id:now:)` trim and drop empty rows. Define repository contracts without SwiftData types.

Use this fixed part-of-speech vocabulary and raw values: `noun`, `verb`, `adj`, `adv`, `pronoun`, `preposition`, `conjunction`, `interjection`, `determiner`, `numeral`, `auxiliary`, `modal`, `phrase`, and `other`. Map API values such as `adjective`, `adverb`, and `exclamation` into those cases.

```swift
public protocol CardRepository: Sendable {
    @MainActor func fetchCards() async throws -> [VocabularyCard]
    @MainActor func save(_ card: VocabularyCard) async throws
    @MainActor func delete(id: UUID) async throws
    @MainActor func duplicateCandidates(for draft: CardDraft, excluding id: UUID?) async throws -> [VocabularyCard]
}

public protocol TagRepository: Sendable {
    @MainActor func fetchTags() async throws -> [Tag]
    @MainActor func create(name: String) async throws -> Tag
    @MainActor func delete(id: UUID) async throws
}

public enum TextNormalizer {
    public static func searchKey(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }
}
```

In `TestFixtures.swift`, define deterministic identifiers and `VocabularyCard.fixture(id:russian:english:tag:)`; every `.fixture(...)` call in Core tests must resolve to that helper rather than hidden global state.

- [ ] **Step 5: Run Core tests and generate the workspace**

Run: `tuist test CardFlipper --no-selective-testing`

Expected: `CoreTests` pass and all production targets compile with their initial source files.

- [ ] **Step 6: Commit the graph and domain foundation**

```bash
git add Tuist.swift Project.swift Tuist Sources/CardFlipperApp Sources/Core Tests/CoreTests
git commit -m "feat: scaffold modular Tuist project and core domain"
```

### Task 2: Study Queue Domain Engine

**Files:**
- Create: `Sources/Core/Study/StudyDirection.swift`
- Create: `Sources/Core/Study/CardShuffler.swift`
- Create: `Sources/Core/Study/StudySession.swift`
- Create: `Tests/CoreTests/StudySessionTests.swift`

**Interfaces:**
- Consumes: `VocabularyCard` from Task 1.
- Produces: `StudyDirection`, `CardShuffler`, `SystemCardShuffler`, `StudySession`, and `StudyResult`.

- [ ] **Step 1: Write failing queue-transition tests**

```swift
import Testing
@testable import Core

@Test func rememberedCardLeavesQueue() throws {
    var session = StudySession(cards: [.fixture(id: 1), .fixture(id: 2)], direction: .russianToEnglish)
    session.reveal()
    try session.remember()
    #expect(session.currentCard?.id == .fixture(2))
    #expect(session.remainingCount == 1)
}

@Test func forgottenCardMovesToEndAndIncrementsCount() throws {
    var session = StudySession(cards: [.fixture(id: 1), .fixture(id: 2)], direction: .englishToRussian)
    session.reveal()
    try session.forget()
    #expect(session.currentCard?.id == .fixture(2))
    #expect(session.forgottenCount == 1)
}

@Test func assessmentBeforeRevealIsRejected() {
    var session = StudySession(cards: [.fixture(id: 1)], direction: .russianToEnglish)
    #expect(throws: StudySessionError.answerNotRevealed) { try session.remember() }
}
```

- [ ] **Step 2: Run the focused tests and observe failure**

Run: `tuist test CardFlipper --test-targets CoreTests/StudySessionTests --no-selective-testing`

Expected: compilation fails because `StudySession` is missing.

- [ ] **Step 3: Implement the deterministic state machine**

```swift
public struct StudySession: Sendable {
    public let direction: StudyDirection
    public let initialCardCount: Int
    public private(set) var queue: [VocabularyCard]
    public private(set) var forgottenCount = 0
    public private(set) var isRevealed = false

    public var currentCard: VocabularyCard? { queue.first }
    public var remainingCount: Int { queue.count }
    public var isComplete: Bool { queue.isEmpty }

    public mutating func reveal() { isRevealed = true }
    public mutating func remember() throws {
        guard isRevealed else { throw StudySessionError.answerNotRevealed }
        queue.removeFirst()
        isRevealed = false
    }
    public mutating func forget() throws {
        guard isRevealed else { throw StudySessionError.answerNotRevealed }
        let forgottenCard = queue.removeFirst()
        queue.append(forgottenCard)
        forgottenCount += 1
        isRevealed = false
    }
}
```

Add `CardShuffler.shuffle(_:)` so ViewModels can inject an identity shuffler in tests and `SystemCardShuffler` can use `cards.shuffled()` in production.

- [ ] **Step 4: Run all Core tests**

Run: `tuist test CardFlipper --test-targets CoreTests --no-selective-testing`

Expected: all Core tests pass.

- [ ] **Step 5: Commit the study engine**

```bash
git add Sources/Core/Study Tests/CoreTests/StudySessionTests.swift
git commit -m "feat: add flashcard study queue engine"
```

### Task 3: SwiftData Schema and Repositories

**Files:**
- Create: `Sources/Data/Persistence/CardFlipperSchema.swift`
- Create: `Sources/Data/Persistence/ModelContainerFactory.swift`
- Create: `Sources/Data/Persistence/Entities/CardEntity.swift`
- Create: `Sources/Data/Persistence/Entities/RussianMeaningEntity.swift`
- Create: `Sources/Data/Persistence/Entities/EnglishVariantEntity.swift`
- Create: `Sources/Data/Persistence/Entities/TagEntity.swift`
- Create: `Sources/Data/Persistence/Mapping/VocabularyCardMapper.swift`
- Create: `Sources/Data/Repositories/SwiftDataCardRepository.swift`
- Create: `Sources/Data/Repositories/SwiftDataTagRepository.swift`
- Create: `Tests/DataTests/SwiftDataRepositoriesTests.swift`
- Create: `Tests/DataTests/TestSupport.swift`

**Interfaces:**
- Consumes: Task 1 repository protocols and domain values.
- Produces: `ModelContainerFactory.makeDefault()`, `ModelContainerFactory.makeInMemory()`, `SwiftDataCardRepository`, and `SwiftDataTagRepository`.

- [ ] **Step 1: Add the `DataTests` target to the manifest and write failing CRUD tests**

```swift
import Testing
@testable import Core
@testable import Data

@MainActor
@Test func savingAndFetchingPreservesOrderedValuesAndTags() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let tagRepository = SwiftDataTagRepository(container: container)
    let cardRepository = SwiftDataCardRepository(container: container)
    let tag = try await tagRepository.create(name: "Work")
    let card = VocabularyCard.fixture(tag: tag)

    try await cardRepository.save(card)
    let fetched = try await cardRepository.fetchCards()

    #expect(fetched == [card])
}

@MainActor
@Test func deletingTagKeepsCard() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repositories = TestRepositories(container: container)
    let tag = try await repositories.tags.create(name: "Exam")
    try await repositories.cards.save(.fixture(tag: tag))
    try await repositories.tags.delete(id: tag.id)
    #expect(try await repositories.cards.fetchCards().count == 1)
    #expect(try await repositories.cards.fetchCards().first?.tags.isEmpty == true)
}
```

`TestSupport.swift` defines `TestRepositories`, fixed UUID helpers, and domain fixtures used by the persistence tests:

```swift
@MainActor
struct TestRepositories {
    let cards: SwiftDataCardRepository
    let tags: SwiftDataTagRepository

    init(container: ModelContainer) {
        cards = SwiftDataCardRepository(container: container)
        tags = SwiftDataTagRepository(container: container)
    }
}
```

- [ ] **Step 2: Run Data tests to verify failure**

Run: `tuist test CardFlipper --test-targets DataTests --no-selective-testing`

Expected: compilation fails because the container factory and repositories are missing.

- [ ] **Step 3: Implement schema entities and cascade/nullify rules**

Use explicit `sortIndex` values for ordered child records. `CardEntity` owns meanings and variants with cascade deletion. Cards and tags use a many-to-many relationship where deleting a tag removes links but preserves cards. Persist part-of-speech raw values as `[String]`.

```swift
@Model
final class CardEntity {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RussianMeaningEntity.card)
    var russianMeanings: [RussianMeaningEntity]
    @Relationship(deleteRule: .cascade, inverse: \EnglishVariantEntity.card)
    var englishVariants: [EnglishVariantEntity]
    @Relationship(deleteRule: .nullify, inverse: \TagEntity.cards)
    var tags: [TagEntity]
}
```

- [ ] **Step 4: Implement mapping and repositories**

Make repository operations `@MainActor` because the shared `ModelContext` is main-actor isolated. Sort child records by `sortIndex` during mapping. Implement duplicate candidates by comparing normalized sets on both language sides, excluding the edited card identifier.

```swift
@MainActor
public final class SwiftDataCardRepository: CardRepository {
    private let context: ModelContext

    public init(container: ModelContainer) {
        context = container.mainContext
    }

    public func fetchCards() async throws -> [VocabularyCard] {
        try context.fetch(FetchDescriptor<CardEntity>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
            .map(VocabularyCardMapper.toDomain)
    }
}
```

Align the protocol isolation/signatures in `Core` with the concrete main-actor implementations: repository methods are `@MainActor async throws` even when no suspension is required.

- [ ] **Step 5: Run Core and Data tests**

Run: `tuist test CardFlipper --no-selective-testing`

Expected: all persistence, mapping, deletion, tag uniqueness, and duplicate tests pass.

- [ ] **Step 6: Commit local persistence**

```bash
git add Project.swift Sources/Core/Repositories Sources/Data/Persistence Sources/Data/Repositories Tests/DataTests
git commit -m "feat: persist vocabulary with SwiftData repositories"
```

### Task 4: Dictionary Lookup and British System Speech

**Files:**
- Create: `Sources/Core/Services/DictionaryService.swift`
- Create: `Sources/Core/Services/SpeechService.swift`
- Create: `Sources/Data/Services/DictionaryDTO.swift`
- Create: `Sources/Data/Services/FreeDictionaryClient.swift`
- Create: `Sources/Data/Services/SystemSpeechService.swift`
- Create: `Tests/DataTests/FreeDictionaryClientTests.swift`
- Modify: `Tests/DataTests/TestSupport.swift`

**Interfaces:**
- Produces: `DictionarySuggestion(ipa:partOfSpeech:)`, `DictionaryService.suggestion(for:)`, `SpeechService.speak(_:)`, `FreeDictionaryClient`, and `SystemSpeechService`.

- [ ] **Step 1: Write failing response-mapping and error tests**

Use a custom `URLProtocol` in an ephemeral `URLSessionConfiguration` to return deterministic JSON.

Mark the dictionary test suite `@Suite(.serialized)` because its URL protocol stub uses shared configured state.

```swift
@Test func mapsFirstNonEmptyIPAAndFirstPartOfSpeech() async throws {
    URLProtocolStub.responseData = #"[{"word":"hello","phonetic":"həˈləʊ","phonetics":[],"meanings":[{"partOfSpeech":"exclamation","definitions":[]}]}]"#.data(using: .utf8)!
    let client = FreeDictionaryClient(session: .stubbed, timeout: 2)
    let suggestion = try await client.suggestion(for: "hello")
    #expect(suggestion == .init(ipa: "həˈləʊ", partOfSpeech: .interjection))
}

@Test func notFoundReturnsNil() async throws {
    URLProtocolStub.statusCode = 404
    let suggestion = try await FreeDictionaryClient(session: .stubbed).suggestion(for: "missing")
    #expect(suggestion == nil)
}
```

Add `URLProtocolStub` and `URLSession.stubbed` to `TestSupport.swift`. Reset status, data, error, and request observer before every test so cases cannot leak state:

```swift
final class URLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var responseData = Data("[]".utf8)
    nonisolated(unsafe) static var responseError: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let error = Self.responseError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `tuist test CardFlipper --test-targets DataTests/FreeDictionaryClientTests --no-selective-testing`

Expected: compilation fails because service types are missing.

- [ ] **Step 3: Implement safe URL construction, timeout, cancellation, and DTO mapping**

```swift
public func suggestion(for text: String) async throws -> DictionarySuggestion? {
    guard var components = URLComponents(string: "https://api.dictionaryapi.dev/api/v2/entries/en/") else {
        throw DictionaryServiceError.invalidRequest
    }
    components.path += text
    guard let url = components.url else { throw DictionaryServiceError.invalidRequest }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw DictionaryServiceError.invalidResponse }
    if http.statusCode == 404 { return nil }
    guard 200..<300 ~= http.statusCode else { throw DictionaryServiceError.server(http.statusCode) }
    return try decoder.decode([DictionaryEntryDTO].self, from: data).first?.suggestion
}
```

Define `FreeDictionaryClient.init(session: URLSession = .shared, timeout: TimeInterval = 5, decoder: JSONDecoder = .init())`; this makes the numeric timeout used above type-correct.

Keep errors typed and non-localized so ViewModels choose UI state. Respect task cancellation; do not convert `CancellationError` into a user-facing failure.

- [ ] **Step 4: Implement system speech behind the protocol**

```swift
@MainActor
public final class SystemSpeechService: SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    public func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        synthesizer.speak(utterance)
    }
}
```

- [ ] **Step 5: Run all Data tests**

Run: `tuist test CardFlipper --test-targets DataTests --no-selective-testing`

Expected: success, 404, invalid JSON, server error, timeout, URL encoding, and cancellation tests pass.

- [ ] **Step 6: Commit language services**

```bash
git add Sources/Core/Services Sources/Data/Services Tests/DataTests/FreeDictionaryClientTests.swift
git commit -m "feat: add dictionary suggestions and British speech"
```

### Task 5: Design System and Localized App Resources

**Files:**
- Create: `Sources/DesignSystem/FlashcardSurface.swift`
- Create: `Sources/DesignSystem/PrimaryActionButton.swift`
- Create: `Sources/DesignSystem/FeedbackGenerator.swift`
- Create: `Resources/CardFlipperApp/Localizable.xcstrings`
- Create: `Resources/CardFlipperApp/Assets.xcassets/Contents.json`
- Create: `Resources/CardFlipperApp/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `Resources/CardFlipperApp/Assets.xcassets/AppIcon.appiconset/Contents.json`

**Interfaces:**
- Produces: `FlashcardSurface`, `PrimaryActionButtonStyle`, and `FeedbackGenerator` used by all feature targets.

- [ ] **Step 1: Add complete Russian and English localization keys**

The String Catalog must contain concrete translations for library, editor, tags, setup, study, results, confirmations, empty states, and errors. Do not place user-facing strings in ViewModels. At minimum, include these exact keys with both English and Russian values:

```text
common.cancel, common.save, common.delete, common.retry, common.close
library.title, library.search, library.add, library.startStudy
library.empty.title, library.empty.message, library.filteredEmpty
card.new.title, card.edit.title, card.russian, card.english
card.addRussian, card.addEnglish, card.ipa, card.partsOfSpeech
card.tags, card.newTag, card.lookup.notFound, card.lookup.failed
card.validation.russian, card.validation.english, card.duplicate.title
tag.delete.title, tag.delete.message
study.setup.title, study.direction, study.russianToEnglish, study.englishToRussian
study.allCards, study.matchingCount, study.start, study.remaining
study.flipHint, study.remember, study.forget, study.exit.title, study.exit.message
study.result.title, study.result.cards, study.result.forgotten
study.result.repeat, study.result.library
data.load.failed, data.save.failed
```

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "library.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Library" } },
        "ru" : { "stringUnit" : { "state" : "translated", "value" : "Библиотека" } }
      }
    },
    "study.remember" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Remember" } },
        "ru" : { "stringUnit" : { "state" : "translated", "value" : "Помню" } }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 2: Implement reusable accessible visual primitives**

```swift
public struct FlashcardSurface<Content: View>: View {
    @ViewBuilder private let content: Content

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
            .contentShape(Rectangle())
    }
}
```

Use Dynamic Type styles, semantic system colors, and no fixed text heights. Implement haptic methods `flip()`, `remember()`, and `forget()` with `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`.

- [ ] **Step 3: Generate and build all support frameworks**

Run: `tuist generate --no-open && tuist build Core Data DesignSystem`

Expected: support frameworks build with no warnings from the new resources or public APIs.

- [ ] **Step 4: Commit design resources**

```bash
git add Sources/DesignSystem Resources/CardFlipperApp Project.swift
git commit -m "feat: add localized accessible design system"
```

### Task 6: Library Feature

**Files:**
- Create: `Sources/LibraryFeature/LibraryViewModel.swift`
- Create: `Sources/LibraryFeature/LibraryView.swift`
- Create: `Sources/LibraryFeature/VocabularyCardRow.swift`
- Create: `Sources/LibraryFeature/TagFilterView.swift`
- Create: `Tests/LibraryFeatureTests/LibraryViewModelTests.swift`
- Create: `Tests/LibraryFeatureTests/TestSupport.swift`
- Modify: `Project.swift`

**Interfaces:**
- Consumes: `CardRepository`, `TagRepository`, `VocabularyCard`, and `Tag`.
- Produces: `LibraryViewModel`, `LibraryView`, and callbacks `onAddCard`, `onEditCard`, and `onStartStudy` for app-owned navigation.

- [ ] **Step 1: Add failing load, search, OR-filter, and deletion tests**

```swift
@MainActor
@Test func searchMatchesEitherLanguage() async {
    let cards = [.fixture(russian: "работа", english: "work"), .fixture(russian: "дом", english: "house")]
    let model = LibraryViewModel(cards: CardRepositoryFake(cards), tags: TagRepositoryFake())
    await model.load()
    model.searchText = "work"
    #expect(model.visibleCards.map(\.russianMeanings.first?.text) == ["работа"])
}

@MainActor
@Test func selectedTagsUseORSemantics() async {
    let model = LibraryViewModel(cards: .taggedFixtures, tags: .fixture)
    await model.load()
    model.selectedTagIDs = [.fixture(1), .fixture(2)]
    #expect(Set(model.visibleCards.map(\.id)) == [.fixture(1), .fixture(2), .fixture(3)])
}
```

In `TestSupport.swift`, implement actor-safe `CardRepositoryFake` and `TagRepositoryFake` with configurable values/errors and captured deleted identifiers. Provide named fixed card/tag fixtures used by the OR test; do not rely on randomly generated UUIDs.

- [ ] **Step 2: Run feature tests and verify failure**

Run: `tuist test CardFlipper --test-targets LibraryFeatureTests --no-selective-testing`

Expected: compilation fails because `LibraryViewModel` is missing.

- [ ] **Step 3: Implement ViewModel state and filtering**

```swift
@MainActor @Observable
public final class LibraryViewModel {
    public private(set) var cards: [VocabularyCard] = []
    public private(set) var tags: [Tag] = []
    public var searchText = ""
    public var selectedTagIDs: Set<UUID> = []
    public private(set) var state: LoadState = .idle
    public var pendingDeletion: VocabularyCard?

    public var visibleCards: [VocabularyCard] {
        cards.filter { card in
            let tagMatch = selectedTagIDs.isEmpty || !Set(card.tags.map(\.id)).isDisjoint(with: selectedTagIDs)
            let query = TextNormalizer.searchKey(searchText)
            let textMatch = query.isEmpty || card.searchableValues.contains { TextNormalizer.searchKey($0).contains(query) }
            return tagMatch && textMatch
        }
    }
}
```

- [ ] **Step 4: Build native library UI and explicit states**

Use `.searchable`, toolbar add/study actions, a horizontal/multi-select tag filter, swipe delete that only sets `pendingDeletion`, and `.confirmationDialog` to perform deletion. Provide empty-library, filtered-empty, loading, and retry views. Expose navigation as closures; do not import other feature modules.

- [ ] **Step 5: Run Library tests and build its framework**

Run: `tuist test CardFlipper --test-targets LibraryFeatureTests --no-selective-testing && tuist build LibraryFeature`

Expected: tests pass and the feature compiles independently.

- [ ] **Step 6: Commit the library**

```bash
git add Project.swift Sources/LibraryFeature Tests/LibraryFeatureTests
git commit -m "feat: add searchable tagged vocabulary library"
```

### Task 7: Card Editor Feature

**Files:**
- Create: `Sources/CardEditorFeature/CardEditorViewModel.swift`
- Create: `Sources/CardEditorFeature/CardEditorView.swift`
- Create: `Sources/CardEditorFeature/RussianMeaningsSection.swift`
- Create: `Sources/CardEditorFeature/EnglishVariantsSection.swift`
- Create: `Sources/CardEditorFeature/TagPickerSection.swift`
- Create: `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift`
- Create: `Tests/CardEditorFeatureTests/TestSupport.swift`
- Modify: `Project.swift`

**Interfaces:**
- Consumes: card/tag repositories, dictionary and speech services, `CardDraft`.
- Produces: `CardEditorViewModel`, `CardEditorView`, `save() -> SaveOutcome`, `lookup(variantID:)`, and `speak(variantID:)`.

- [ ] **Step 1: Write failing save, duplicate, lookup, cancellation, and preservation tests**

```swift
@MainActor
@Test func dictionarySuggestionUpdatesOnlyMatchingVariant() async {
    let dictionary = DictionaryServiceFake(result: .init(ipa: "wɜːd", partOfSpeech: .noun))
    let model = CardEditorViewModel.newCard(cards: .empty, tags: .empty, dictionary: dictionary, speech: .noop)
    model.englishVariants[0].text = "word"
    await model.lookup(variantID: model.englishVariants[0].id)
    #expect(model.englishVariants[0].ipa == "wɜːd")
    #expect(model.englishVariants[0].partsOfSpeech == [.noun])
}

@MainActor
@Test func duplicateRequiresExplicitConfirmation() async {
    let model = CardEditorViewModel.newCard(cards: .duplicate, tags: .empty, dictionary: .none, speech: .noop)
    model.russianMeanings = [.init(text: "слово")]
    model.englishVariants = [.init(text: "word")]
    #expect(await model.save() == .needsDuplicateConfirmation)
    #expect(model.isPresented == true)
}
```

`TestSupport.swift` supplies `CardRepositoryFake`, `TagRepositoryFake`, `DictionaryServiceFake`, and `SpeechServiceSpy`. Each fake exposes concrete result/error properties and captures calls, allowing tests to verify cancellation, duplicate confirmation, created tag selection, preserved input, and spoken text.

- [ ] **Step 2: Run tests and verify failure**

Run: `tuist test CardFlipper --test-targets CardEditorFeatureTests --no-selective-testing`

Expected: compilation fails because editor types are missing.

- [ ] **Step 3: Implement editor state, validation, debounce, and save outcomes**

```swift
public enum SaveOutcome: Equatable { case saved, invalid, needsDuplicateConfirmation, failed }

@MainActor @Observable
public final class CardEditorViewModel {
    public var russianMeanings: [RussianMeaningInput]
    public var englishVariants: [EnglishVariantInput]
    public var selectedTagIDs: Set<UUID>
    public private(set) var lookupState: [UUID: LookupState] = [:]
    public private(set) var saveError: SaveError?
    private var lookupTasks: [UUID: Task<Void, Never>] = [:]

    public func scheduleLookup(variantID: UUID) {
        lookupTasks[variantID]?.cancel()
        lookupTasks[variantID] = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await lookup(variantID: variantID)
        }
    }
}
```

Do not clear inputs on validation, lookup, or repository errors. `confirmDuplicateAndSave()` bypasses only the duplicate warning, not validation. Creating a tag trims its name, selects it, and keeps the editor open.

- [ ] **Step 4: Build the form UI**

Use a `Form` with independently addable/removable ordered rows. Provide fixed multi-select part-of-speech chips, IPA input, lookup progress/error, speech button, tag creation, Cancel/Save toolbar items, inline validation, and a duplicate confirmation alert. Keep the sheet presented after failures.

- [ ] **Step 5: Run editor tests and build**

Run: `tuist test CardFlipper --test-targets CardEditorFeatureTests --no-selective-testing && tuist build CardEditorFeature`

Expected: editor state tests pass and no feature imports `Data` or SwiftData.

- [ ] **Step 6: Commit the editor**

```bash
git add Project.swift Sources/CardEditorFeature Tests/CardEditorFeatureTests
git commit -m "feat: add multi-value vocabulary card editor"
```

### Task 8: Study Setup, Session, and Result UI

**Files:**
- Create: `Sources/StudyFeature/StudySetupViewModel.swift`
- Create: `Sources/StudyFeature/StudySetupView.swift`
- Create: `Sources/StudyFeature/StudySessionViewModel.swift`
- Create: `Sources/StudyFeature/StudySessionView.swift`
- Create: `Sources/StudyFeature/StudyCardView.swift`
- Create: `Sources/StudyFeature/StudyResultView.swift`
- Create: `Tests/StudyFeatureTests/StudySetupViewModelTests.swift`
- Create: `Tests/StudyFeatureTests/StudySessionViewModelTests.swift`
- Create: `Tests/StudyFeatureTests/TestSupport.swift`
- Modify: `Project.swift`

**Interfaces:**
- Consumes: `VocabularyCard`, `Tag`, `StudyDirection`, `StudySession`, `CardShuffler`, `SpeechService`.
- Produces: `StudyConfiguration`, `StudySetupView`, `StudySessionView`, and result callbacks `onRepeat` and `onFinish`.

- [ ] **Step 1: Write failing setup and session ViewModel tests**

```swift
@MainActor
@Test func noSelectedTagsIncludesEveryCard() {
    let model = StudySetupViewModel(cards: [.fixture(id: 1), .fixture(id: 2)], tags: [])
    #expect(model.matchingCards.count == 2)
}

@MainActor
@Test func assessmentIsHiddenUntilReveal() {
    let model = StudySessionViewModel(configuration: .fixture, shuffler: IdentityShuffler(), speech: .noop)
    #expect(model.canAssess == false)
    model.reveal()
    #expect(model.canAssess == true)
}

@MainActor
@Test func resultPreservesConfigurationForRepeat() throws {
    let model = StudySessionViewModel(configuration: .singleCard, shuffler: IdentityShuffler(), speech: .noop)
    model.reveal()
    try model.remember()
    #expect(model.result == .init(uniqueCardCount: 1, forgottenCount: 0))
    #expect(model.repeatConfiguration == .singleCard)
}
```

`TestSupport.swift` defines `IdentityShuffler`, `ReversingShuffler`, `SpeechServiceSpy`, deterministic tags/cards, and the `.singleCard`/`.fixture` configurations used by these tests.

- [ ] **Step 2: Run tests and confirm failure**

Run: `tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing`

Expected: compilation fails because study feature types are missing.

- [ ] **Step 3: Implement configuration and ViewModels**

`StudyConfiguration` stores the fixed direction, selected tag identifiers, and original matching cards. Setup uses OR semantics and exposes `canStart`. Session wraps the Core state machine, emits haptics, delegates English speech, exposes exit confirmation, and creates a result only when the queue is empty.

```swift
public struct StudyConfiguration: Equatable, Sendable {
    public let direction: StudyDirection
    public let selectedTagIDs: Set<UUID>
    public let cards: [VocabularyCard]
}

@MainActor @Observable
public final class StudySessionViewModel {
    public private(set) var session: StudySession
    public private(set) var result: StudyResult?
    public var isExitConfirmationPresented = false
    public var canAssess: Bool { session.isRevealed && !session.isComplete }
}
```

- [ ] **Step 4: Build accessible setup, flip, assessment, and result views**

Use a segmented direction picker, multi-select tag list, matching count, and disabled start action for zero matches. The card front/back depends on direction. English fronts show IPA and parts of speech. Apply a 3D rotation when Reduce Motion is false and an opacity transition otherwise. Move accessibility focus to the answer after reveal and the new prompt after assessment. Provide explicit symbols and labels for both actions.

- [ ] **Step 5: Run Study feature tests and build**

Run: `tuist test CardFlipper --test-targets StudyFeatureTests --no-selective-testing && tuist build StudyFeature`

Expected: filtering, reveal gating, queue transitions, result, repeat configuration, and exit-state tests pass.

- [ ] **Step 6: Commit the study flow**

```bash
git add Project.swift Sources/StudyFeature Tests/StudyFeatureTests
git commit -m "feat: add configurable flashcard study flow"
```

### Task 9: Application Composition and End-to-End Verification

**Files:**
- Create: `Sources/CardFlipperApp/AppContainer.swift`
- Create: `Sources/CardFlipperApp/RootView.swift`
- Modify: `Sources/CardFlipperApp/CardFlipperApp.swift`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`
- Create: `README.md`

**Interfaces:**
- Consumes all production module APIs.
- Produces the runnable `CardFlipper` app with app-owned routes, editor sheet state, and full-screen study flow.

- [ ] **Step 1: Implement the composition root**

```swift
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let cards: any CardRepository
    let tags: any TagRepository
    let dictionary: any DictionaryService
    let speech: any SpeechService
    let shuffler: any CardShuffler

    init() throws {
        modelContainer = try ModelContainerFactory.makeDefault()
        cards = SwiftDataCardRepository(container: modelContainer)
        tags = SwiftDataTagRepository(container: modelContainer)
        dictionary = FreeDictionaryClient()
        speech = SystemSpeechService()
        shuffler = SystemCardShuffler()
    }
}
```

Handle container-construction failure with a recoverable root error screen instead of force-unwrapping or crashing.

- [ ] **Step 2: Implement app-owned navigation and refresh contracts**

`RootView` owns `NavigationPath`, optional editor presentation, and optional study configuration. Library callbacks open the editor or setup. Successful saves/deletes reload the library. Completing or abandoning study returns to the library without persisting session state. Repeat creates a new shuffled session from the unchanged configuration.

```swift
enum AppRoute: Hashable {
    case studySetup
}

@MainActor @Observable
final class AppNavigationState {
    var path: [AppRoute] = []
    var editorCardID: UUID?
    var activeStudy: StudyConfiguration?
}
```

Present the session with `fullScreenCover(item:)` using an identifiable app-owned wrapper around `activeStudy`. Keep complete configuration values in `AppNavigationState`; do not force them into `NavigationPath` or weaken domain types merely to obtain `Hashable` conformance.

- [ ] **Step 3: Complete localization and perform static boundary checks**

Run:

```bash
rg -n 'import SwiftData|import Data' Sources/LibraryFeature Sources/CardEditorFeature Sources/StudyFeature
rg -n 'Text\("[A-ZА-Я]|Button\("[A-ZА-Я]|navigationTitle\("[A-ZА-Я]' Sources
```

Expected: no SwiftData/Data imports in feature modules and no unintended hard-coded user-facing strings.

- [ ] **Step 4: Run the full generated-project test and build suite**

Run:

```bash
tuist clean
tuist generate --no-open
tuist test CardFlipper --no-selective-testing
tuist build CardFlipper
git diff --check
```

Expected: project generation succeeds, every Swift Testing suite passes, the app builds for the available iOS simulator SDK, and Git reports no whitespace errors.

- [ ] **Step 5: Perform the manual acceptance walkthrough in Simulator**

Verify each approved acceptance criterion in Russian and English:

1. Empty library appears with add action.
2. Create a tag and a card with two values on each side, IPA, and multiple parts of speech.
3. Trigger a successful suggestion and confirm offline/not-found remains editable.
4. Search both languages, filter tags, edit, delete with confirmation, and verify duplicate warning.
5. Study both directions; ensure English fronts show IPA/parts of speech.
6. Confirm “Don’t remember” cycles to the end and “Remember” eventually completes.
7. Repeat from the result and confirm a new shuffle.
8. Force-quit/relaunch and confirm vocabulary persists while session/result does not.
9. Check light/dark mode, largest Dynamic Type, VoiceOver focus, and Reduce Motion.

- [ ] **Step 6: Write setup and verification documentation**

README commands must be exact:

```markdown
## Generate
`tuist generate`

## Test
`tuist test CardFlipper --no-selective-testing`

## Build
`tuist build CardFlipper`
```

Also document Xcode 26.0.1, Tuist 4.40.0, the iOS 18 floor, the local-only data policy, and the optional Free Dictionary API behavior.

- [ ] **Step 7: Commit the integrated application**

```bash
git add Sources/CardFlipperApp Resources/CardFlipperApp README.md
git commit -m "feat: integrate CardFlipper application"
```

- [ ] **Step 8: Record final repository state**

Run: `git status --short --branch && git log --oneline -10`

Expected: clean working tree on `main` with the nine implementation commits following the approved design and plan commits.

<flows>

### F1 — First launch → create → reopen and edit

1. Launch with an empty local store and confirm the intentional empty Library state.
2. Open Add Card, create a tag, enter two Russian meanings and two English variants with IPA and parts of speech, then save.
3. Confirm the saved card appears in Library and can be found from both a Russian and an English search.
4. Open the saved row, change one value, save, and confirm the edited value appears in Library.
5. Least-discoverable action: determine whether tapping the vocabulary row to edit is obvious without instruction.

### F2 — Library → study → repeat → finish

1. Start Study from a non-empty Library, explicitly choose a direction, and start the session.
2. Reveal a card, choose Don't remember, and confirm it returns after the other queued cards.
3. Reveal and remember every card, then confirm the result screen appears.
4. Tap Repeat and confirm a fresh session remains presented; finish and confirm the Library returns.
5. Least-discoverable action: determine whether tapping the card to reveal it is obvious before the hint is read.

### F3 — Persistence and transient-session reset

1. Launch with a seeded vocabulary, enter a study session, then terminate the app before completion.
2. Relaunch and confirm vocabulary remains while the study/session result is not restored.
3. Delete a card with confirmation and verify the Library refreshes without reopening the app.
4. Least-discoverable action: determine whether destructive row actions are discoverable without accidental activation.

</flows>
