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
    var suspendsDuplicateCheck = false
    private(set) var savedCards: [VocabularyCard] = []
    private(set) var duplicateDrafts: [CardDraft] = []
    private(set) var duplicateExclusions: [UUID?] = []
    private var duplicateContinuation: CheckedContinuation<[VocabularyCard], Error>?

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

    func addTags(ids: Set<UUID>, toCardIDs cardIDs: Set<UUID>) async throws {}

    func delete(id: UUID) async throws {}

    func duplicateCandidates(
        for draft: CardDraft,
        excluding id: UUID?
    ) async throws -> [VocabularyCard] {
        duplicateDrafts.append(draft)
        duplicateExclusions.append(id)
        if let duplicateError { throw duplicateError }
        if suspendsDuplicateCheck {
            return try await withCheckedThrowingContinuation { continuation in
                duplicateContinuation = continuation
            }
        }
        return duplicateResult
    }

    var hasSuspendedDuplicateCheck: Bool {
        duplicateContinuation != nil
    }

    func resumeDuplicateCheck() {
        duplicateContinuation?.resume(returning: duplicateResult)
        duplicateContinuation = nil
    }
}

@MainActor
final class TagRepositoryFake: TagRepository {
    var fetchedTags: [Tag]
    var fetchError: EditorTestError?
    var createError: EditorTestError?
    var createdTag: Tag
    var suspendsFetch = false
    private(set) var createdNames: [String] = []
    private var fetchContinuation: CheckedContinuation<[Tag], Error>?

    init(
        fetchedTags: [Tag] = [],
        fetchError: EditorTestError? = nil,
        createError: EditorTestError? = nil,
        createdTag: Tag = .study,
        suspendsFetch: Bool = false
    ) {
        self.fetchedTags = fetchedTags
        self.fetchError = fetchError
        self.createError = createError
        self.createdTag = createdTag
        self.suspendsFetch = suspendsFetch
    }

    func fetchTags() async throws -> [Tag] {
        if let fetchError { throw fetchError }
        if suspendsFetch {
            return try await withCheckedThrowingContinuation { continuation in
                fetchContinuation = continuation
            }
        }
        return fetchedTags
    }

    var hasSuspendedFetch: Bool {
        fetchContinuation != nil
    }

    func resumeFetch(with tags: [Tag]) {
        fetchContinuation?.resume(returning: tags)
        fetchContinuation = nil
    }

    func create(name: String) async throws -> Tag {
        createdNames.append(name)
        if let createError { throw createError }
        if !fetchedTags.contains(where: { $0.id == createdTag.id }) {
            fetchedTags.append(createdTag)
        }
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
    private var cancelledRequests: Set<String> = []

    func suggestion(for text: String) async throws -> DictionarySuggestion? {
        calls.append(text)
        let suggestion = await withCheckedContinuation { continuation in
            continuations[text] = continuation
        }
        if Task.isCancelled {
            cancelledRequests.insert(text)
        }
        return suggestion
    }

    func hasRequest(for text: String) -> Bool {
        continuations[text] != nil
    }

    func resolve(_ text: String, with suggestion: DictionarySuggestion?) {
        continuations.removeValue(forKey: text)?.resume(returning: suggestion)
    }

    func wasCancelled(_ text: String) -> Bool {
        cancelledRequests.contains(text)
    }
}

actor LookupSleepRecorder {
    private(set) var requestedDurations: [Duration] = []

    func sleep(for duration: Duration) async throws {
        requestedDurations.append(duration)
        throw CancellationError()
    }
}

actor ControlledLookupSleep {
    private var continuation: CheckedContinuation<Void, Never>?

    var hasSuspendedSleep: Bool {
        continuation != nil
    }

    func sleep(for duration: Duration) async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
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
                partsOfSpeech: [.noun],
                usageExamples: [
                    UsageExample(
                        id: .editorFixture(103),
                        text: "This word is useful.",
                        partOfSpeech: .noun
                    ),
                ]
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
