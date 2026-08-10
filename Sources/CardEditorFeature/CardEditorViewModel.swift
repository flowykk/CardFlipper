import Core
import Foundation
import Observation

public struct RussianMeaningInput: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

public struct EnglishVariantInput: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var ipa: String
    public var partsOfSpeech: [PartOfSpeech]

    public init(
        id: UUID = UUID(),
        text: String = "",
        ipa: String? = nil,
        partsOfSpeech: [PartOfSpeech] = []
    ) {
        self.id = id
        self.text = text
        self.ipa = ipa ?? ""
        self.partsOfSpeech = partsOfSpeech
    }
}

public enum SaveOutcome: Equatable, Sendable {
    case saved
    case invalid
    case needsDuplicateConfirmation
    case failed
}

public enum SaveError: Equatable, Sendable {
    case duplicateCheck
    case persistence
}

public enum LookupState: Equatable, Sendable {
    case loading
    case suggested
    case notFound
    case failed
}

public enum TagCreationOutcome: Equatable, Sendable {
    case created
    case invalid
    case failed
}

@MainActor
@Observable
public final class CardEditorViewModel {
    public var russianMeanings: [RussianMeaningInput]
    public var englishVariants: [EnglishVariantInput]
    public var selectedTagIDs: Set<UUID>
    public private(set) var availableTags: [Tag]
    public var newTagName = ""
    public private(set) var lookupState: [UUID: LookupState] = [:]
    public private(set) var saveError: SaveError?
    public private(set) var tagLoadError = false
    public private(set) var tagCreationError = false
    public var isDuplicateConfirmationPresented = false
    public private(set) var isPresented = true

    private let existingCard: VocabularyCard?
    private let cardRepository: any CardRepository
    private let tagRepository: any TagRepository
    private let dictionaryService: any DictionaryService
    private let speechService: any SpeechService
    private let now: @MainActor () -> Date
    private let lookupDebounce: Duration
    private let lookupSleep: @Sendable (Duration) async throws -> Void
    private var lookupTasks: [UUID: Task<Void, Never>] = [:]
    private var lookupRequestIDs: [UUID: UUID] = [:]

    public init(
        card: VocabularyCard?,
        cards: any CardRepository,
        tags: any TagRepository,
        dictionary: any DictionaryService,
        speech: any SpeechService,
        now: @escaping @MainActor () -> Date = Date.init,
        lookupDebounce: Duration = .milliseconds(450),
        lookupSleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        existingCard = card
        cardRepository = cards
        tagRepository = tags
        dictionaryService = dictionary
        speechService = speech
        self.now = now
        self.lookupDebounce = lookupDebounce
        self.lookupSleep = lookupSleep

        if let card {
            russianMeanings = card.russianMeanings.map {
                RussianMeaningInput(id: $0.id, text: $0.text)
            }
            englishVariants = card.englishVariants.map {
                EnglishVariantInput(
                    id: $0.id,
                    text: $0.text,
                    ipa: $0.ipa,
                    partsOfSpeech: $0.partsOfSpeech
                )
            }
            selectedTagIDs = Set(card.tags.map(\.id))
            availableTags = card.tags
        } else {
            russianMeanings = [RussianMeaningInput()]
            englishVariants = [EnglishVariantInput()]
            selectedTagIDs = []
            availableTags = []
        }
    }

    public static func newCard(
        cards: any CardRepository,
        tags: any TagRepository,
        dictionary: any DictionaryService,
        speech: any SpeechService,
        now: @escaping @MainActor () -> Date = Date.init
    ) -> CardEditorViewModel {
        CardEditorViewModel(
            card: nil,
            cards: cards,
            tags: tags,
            dictionary: dictionary,
            speech: speech,
            now: now
        )
    }

    public static func edit(
        card: VocabularyCard,
        cards: any CardRepository,
        tags: any TagRepository,
        dictionary: any DictionaryService,
        speech: any SpeechService,
        now: @escaping @MainActor () -> Date = Date.init
    ) -> CardEditorViewModel {
        CardEditorViewModel(
            card: card,
            cards: cards,
            tags: tags,
            dictionary: dictionary,
            speech: speech,
            now: now
        )
    }

    public var validationErrors: [CardDraft.ValidationError] {
        draft.validationErrors
    }

    public func addRussianMeaning() {
        russianMeanings.append(RussianMeaningInput())
    }

    public func removeRussianMeaning(id: UUID) {
        russianMeanings.removeAll { $0.id == id }
    }

    public func addEnglishVariant() {
        englishVariants.append(EnglishVariantInput())
    }

    public func removeEnglishVariant(id: UUID) {
        lookupTasks[id]?.cancel()
        lookupTasks[id] = nil
        lookupRequestIDs[id] = nil
        lookupState[id] = nil
        englishVariants.removeAll { $0.id == id }
    }

    public func togglePartOfSpeech(
        _ partOfSpeech: PartOfSpeech,
        variantID: UUID
    ) {
        guard let index = englishVariants.firstIndex(where: { $0.id == variantID }) else {
            return
        }

        if let partIndex = englishVariants[index].partsOfSpeech.firstIndex(of: partOfSpeech) {
            englishVariants[index].partsOfSpeech.remove(at: partIndex)
        } else {
            englishVariants[index].partsOfSpeech.append(partOfSpeech)
        }
    }

    public func loadTags() async {
        do {
            let loadedTags = try await tagRepository.fetchTags()
            guard !Task.isCancelled else { return }
            availableTags = loadedTags
            selectedTagIDs.formIntersection(loadedTags.map(\.id))
            tagLoadError = false
        } catch is CancellationError {
            return
        } catch {
            tagLoadError = true
        }
    }

    @discardableResult
    public func createTag() async -> TagCreationOutcome {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .invalid }

        do {
            let tag = try await tagRepository.create(name: trimmedName)
            guard !Task.isCancelled else { return .failed }
            if !availableTags.contains(where: { $0.id == tag.id }) {
                availableTags.append(tag)
            }
            selectedTagIDs.insert(tag.id)
            newTagName = ""
            tagCreationError = false
            return .created
        } catch is CancellationError {
            return .failed
        } catch {
            tagCreationError = true
            return .failed
        }
    }

    @discardableResult
    public func save() async -> SaveOutcome {
        saveError = nil
        isDuplicateConfirmationPresented = false
        let currentDraft = draft
        guard currentDraft.validationErrors.isEmpty else { return .invalid }

        do {
            let duplicates = try await cardRepository.duplicateCandidates(
                for: currentDraft,
                excluding: existingCard?.id
            )
            guard !Task.isCancelled else { return .failed }
            if !duplicates.isEmpty {
                isDuplicateConfirmationPresented = true
                return .needsDuplicateConfirmation
            }
        } catch is CancellationError {
            return .failed
        } catch {
            saveError = .duplicateCheck
            return .failed
        }

        return await saveValidated(currentDraft)
    }

    @discardableResult
    public func confirmDuplicateAndSave() async -> SaveOutcome {
        isDuplicateConfirmationPresented = false
        saveError = nil
        let currentDraft = draft
        guard currentDraft.validationErrors.isEmpty else { return .invalid }
        return await saveValidated(currentDraft)
    }

    public func scheduleLookup(variantID: UUID) {
        _ = replaceLookup(variantID: variantID, debounce: lookupDebounce)
    }

    public func lookup(variantID: UUID) async {
        guard let operation = replaceLookup(variantID: variantID, debounce: nil) else {
            return
        }

        await withTaskCancellationHandler {
            await operation.task.value
        } onCancel: {
            operation.task.cancel()
        }

        guard isCurrentLookup(
            variantID: variantID,
            requestID: operation.requestID,
            text: operation.text
        ) else {
            return
        }
    }

    public func speak(variantID: UUID) {
        guard let variant = englishVariants.first(where: { $0.id == variantID }) else {
            return
        }
        let text = variant.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        speechService.speak(text)
    }

    public func cancel() {
        for task in lookupTasks.values {
            task.cancel()
        }
        lookupTasks.removeAll()
        lookupRequestIDs.removeAll()
        isPresented = false
    }

    private var draft: CardDraft {
        CardDraft(
            russianMeanings: russianMeanings.map(\.text),
            englishVariants: englishVariants.map {
                EnglishVariantDraft(
                    text: $0.text,
                    ipa: $0.ipa,
                    partsOfSpeech: $0.partsOfSpeech
                )
            },
            tagIDs: availableTags
                .filter { selectedTagIDs.contains($0.id) }
                .map(\.id)
        )
    }

    private func saveValidated(_ currentDraft: CardDraft) async -> SaveOutcome {
        let timestamp = now()

        do {
            let generatedCard = try currentDraft.makeCard(
                id: existingCard?.id ?? UUID(),
                russianMeaningIDs: russianMeanings.map(\.id),
                englishVariantIDs: englishVariants.map(\.id),
                now: timestamp
            )
            let resolvedTags = availableTags.filter {
                selectedTagIDs.contains($0.id)
            }
            let card = VocabularyCard(
                id: generatedCard.id,
                russianMeanings: generatedCard.russianMeanings,
                englishVariants: generatedCard.englishVariants,
                tags: resolvedTags,
                createdAt: existingCard?.createdAt ?? generatedCard.createdAt,
                updatedAt: timestamp
            )
            try await cardRepository.save(card)
            guard !Task.isCancelled else { return .failed }
            isPresented = false
            return .saved
        } catch is CancellationError {
            return .failed
        } catch {
            saveError = .persistence
            return .failed
        }
    }

    private struct LookupOperation {
        let requestID: UUID
        let text: String
        let task: Task<Void, Never>
    }

    private func replaceLookup(
        variantID: UUID,
        debounce: Duration?
    ) -> LookupOperation? {
        lookupTasks[variantID]?.cancel()

        guard let variant = englishVariants.first(where: { $0.id == variantID }) else {
            return nil
        }
        let text = variant.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            lookupRequestIDs[variantID] = nil
            lookupState[variantID] = nil
            lookupTasks[variantID] = nil
            return nil
        }

        let requestID = UUID()
        lookupRequestIDs[variantID] = requestID
        lookupState[variantID] = .loading

        let task = Task { [weak self] in
            guard let self else { return }

            if let debounce {
                do {
                    try await self.lookupSleep(debounce)
                } catch {
                    return
                }
                guard !Task.isCancelled,
                      self.isCurrentLookup(
                        variantID: variantID,
                        requestID: requestID,
                        text: text
                      ) else {
                    return
                }
            }

            await self.performLookup(
                variantID: variantID,
                requestID: requestID,
                text: text
            )
            guard self.isCurrentLookup(
                variantID: variantID,
                requestID: requestID,
                text: text
            ) else {
                return
            }
            self.lookupTasks[variantID] = nil
        }
        lookupTasks[variantID] = task

        return LookupOperation(requestID: requestID, text: text, task: task)
    }

    private func performLookup(
        variantID: UUID,
        requestID: UUID,
        text: String
    ) async {
        do {
            let suggestion = try await dictionaryService.suggestion(for: text)
            try Task.checkCancellation()
            guard isCurrentLookup(
                variantID: variantID,
                requestID: requestID,
                text: text
            ), let index = englishVariants.firstIndex(where: { $0.id == variantID }) else {
                return
            }

            guard let suggestion else {
                lookupState[variantID] = .notFound
                return
            }

            var appliedSuggestion = false
            if let ipa = suggestion.ipa?.trimmingCharacters(in: .whitespacesAndNewlines),
               !ipa.isEmpty {
                englishVariants[index].ipa = ipa
                appliedSuggestion = true
            }
            if let partOfSpeech = suggestion.partOfSpeech {
                if !englishVariants[index].partsOfSpeech.contains(partOfSpeech) {
                    englishVariants[index].partsOfSpeech.append(partOfSpeech)
                }
                appliedSuggestion = true
            }
            lookupState[variantID] = appliedSuggestion ? .suggested : .notFound
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentLookup(
                variantID: variantID,
                requestID: requestID,
                text: text
            ) else {
                return
            }
            lookupState[variantID] = .failed
        }
    }

    private func isCurrentLookup(
        variantID: UUID,
        requestID: UUID,
        text: String
    ) -> Bool {
        guard lookupRequestIDs[variantID] == requestID,
              let variant = englishVariants.first(where: { $0.id == variantID }) else {
            return false
        }
        return variant.text.trimmingCharacters(in: .whitespacesAndNewlines) == text
    }
}
