import Foundation
@testable import Core
@testable import CardEditorFeature

enum EditorTestError: Error, Sendable {
    case duplicateLookup
    case save
    case tags
    case dictionary
}

@MainActor
final class CardRepositoryFake: CardRepository {
    var duplicateResult: [VocabularyCard]
    var duplicateError: EditorTestError?
    var saveError: EditorTestError?
    private(set) var savedCards: [VocabularyCard] = []
    private(set) var duplicateDrafts: [CardDraft] = []
    private(set) var duplicateExclusions: [UUID?] = []

    init(
        duplicateResult: [VocabularyCard] = [],
        duplicateError: EditorTestError? = nil,
        saveError: EditorTestError? = nil
    ) {
        self.duplicateResult = duplicateResult
        self.duplicateError = duplicateError
        self.saveError = saveError
    }

    func fetchCards() async throws -> [VocabularyCard] { [] }

    func save(_ card: VocabularyCard) async throws {
        if let saveError { throw saveError }
        savedCards.append(card)
    }

    func delete(id: UUID) async throws {}

    func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard] {
        duplicateDrafts.append(draft)
        duplicateExclusions.append(id)
        if let duplicateError { throw duplicateError }
        return duplicateResult
    }
}

@MainActor
final class TagRepositoryFake: TagRepository {
    var fetchedTags: [Tag]
    var fetchError: EditorTestError?
    var createError: EditorTestError?
    var createdTag: Tag
    private(set) var createdNames: [String] = []

    init(
        fetchedTags: [Tag] = [],
        fetchError: EditorTestError? = nil,
        createError: EditorTestError? = nil,
        createdTag: Tag = .study
    ) {
        self.fetchedTags = fetchedTags
        self.fetchError = fetchError
        self.createError = createError
        self.createdTag = createdTag
    }

    func fetchTags() async throws -> [Tag] {
        if let fetchError { throw fetchError }
        return fetchedTags
    }

    func create(name: String) async throws -> Tag {
        createdNames.append(name)
        if let createError { throw createError }
        return createdTag
    }

    func delete(id: UUID) async throws {}
}

actor DictionaryServiceFake: DictionaryService {
    var result: Result<DictionarySuggestion?, EditorTestError>
    private(set) var calls: [String] = []

    init(
        result: Result<DictionarySuggestion?, EditorTestError> = .success(nil)
    ) {
        self.result = result
    }

    func suggestion(for text: String) async throws -> DictionarySuggestion? {
        calls.append(text)
        return try result.get()
    }
}

actor ControlledDictionaryService: DictionaryService {
    private var continuations: [String: CheckedContinuation<DictionarySuggestion?, Never>] = [:]
    private(set) var calls: [String] = []

    func suggestion(for text: String) async throws -> DictionarySuggestion? {
        calls.append(text)
        return await withCheckedContinuation { continuation in
            continuations[text] = continuation
        }
    }

    func hasRequest(for text: String) -> Bool {
        continuations[text] != nil
    }

    func resolve(_ text: String, with suggestion: DictionarySuggestion?) {
        continuations.removeValue(forKey: text)?.resume(returning: suggestion)
    }
}

actor LookupSleepRecorder {
    private(set) var requestedDurations: [Duration] = []

    func sleep(for duration: Duration) async throws {
        requestedDurations.append(duration)
        throw CancellationError()
    }
}

@MainActor
final class SpeechServiceSpy: SpeechService {
    private(set) var spokenTexts: [String] = []

    func speak(_ text: String) {
        spokenTexts.append(text)
    }
}

extension UUID {
    static func editorFixture(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

extension Tag {
    static let work = Tag(id: .editorFixture(1), name: "Work")
    static let exam = Tag(id: .editorFixture(2), name: "Exam")
    static let study = Tag(id: .editorFixture(3), name: "Study")
}

extension VocabularyCard {
    static let duplicate = VocabularyCard(
        id: .editorFixture(100),
        russianMeanings: [
            RussianMeaning(id: .editorFixture(101), text: "слово"),
        ],
        englishVariants: [
            EnglishVariant(
                id: .editorFixture(102),
                text: "word",
                ipa: "wɜːd",
                partsOfSpeech: [.noun]
            ),
        ],
        tags: [.work],
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: Date(timeIntervalSince1970: 200)
    )
}

@MainActor
func makeNewEditor(
    cards: CardRepositoryFake = CardRepositoryFake(),
    tags: TagRepositoryFake = TagRepositoryFake(),
    dictionary: any DictionaryService = DictionaryServiceFake(),
    speech: SpeechServiceSpy = SpeechServiceSpy()
) -> CardEditorViewModel {
    CardEditorViewModel.newCard(
        cards: cards,
        tags: tags,
        dictionary: dictionary,
        speech: speech,
        now: { Date(timeIntervalSince1970: 1_000) }
    )
}

func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
