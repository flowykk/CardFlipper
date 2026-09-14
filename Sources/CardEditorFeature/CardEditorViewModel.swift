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

public struct UsageExampleInput: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var partOfSpeech: PartOfSpeech?

    public init(
        id: UUID = UUID(),
        text: String = "",
        partOfSpeech: PartOfSpeech? = nil
    ) {
        self.id = id
        self.text = text
        self.partOfSpeech = partOfSpeech
    }
}

public struct EnglishVariantInput: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var ipa: String
    public var partsOfSpeech: [PartOfSpeech]
    public var usageExamples: [UsageExampleInput]

    public init(
        id: UUID = UUID(),
        text: String = "",
        ipa: String? = nil,
        partsOfSpeech: [PartOfSpeech] = [],
        usageExamples: [UsageExampleInput] = []
    ) {
        self.id = id
        self.text = text
        self.ipa = ipa ?? ""
        self.partsOfSpeech = partsOfSpeech
        self.usageExamples = usageExamples
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
    case conflict
    case notFound
    case failed
}

public enum SuggestedField<Value: Equatable & Sendable>: Equatable, Sendable {
    case empty
    case suggested(Value)
    case userEdited(Value)
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
    public private(set) var pendingDictionarySuggestions: [UUID: DictionarySuggestion] = [:]
    public private(set) var saveError: SaveError?
    public private(set) var tagLoadError = false
    public private(set) var tagCreationError = false
    public var isDuplicateConfirmationPresented = false
    public private(set) var isPresented = true
    public private(set) var isSaving = false
    public private(set) var didSave = false
    public private(set) var savedCard: VocabularyCard?
    public private(set) var hasAttemptedSave = false
    public var expandedMetadataVariantIDs: Set<UUID>

    private let existingCard: VocabularyCard?
    private let draftCardID: UUID
    private let initialContent: EditorContentSnapshot
    private let cardRepository: any CardRepository
    private let tagRepository: any TagRepository
    private let dictionaryService: any DictionaryService
    private let speechService: any SpeechService
    private let now: @MainActor () -> Date
    private let lookupDebounce: Duration
    private let lookupSleep: @Sendable (Duration) async throws -> Void
    private var lookupTasks: [UUID: Task<Void, Never>] = [:]
    private var lookupRequestIDs: [UUID: UUID] = [:]
    private var ipaFieldStates: [UUID: SuggestedField<String>] = [:]
    private var partsOfSpeechFieldStates: [UUID: SuggestedField<[PartOfSpeech]>] = [:]
    private var pendingDuplicateSaveSnapshot: SaveSnapshot?

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

        let initialRussianMeanings: [RussianMeaningInput]
        let initialEnglishVariants: [EnglishVariantInput]
        let initialSelectedTagIDs: Set<UUID>
        let initialAvailableTags: [Tag]

        if let card {
            initialRussianMeanings = card.russianMeanings.map {
                RussianMeaningInput(id: $0.id, text: $0.text)
            }
            initialEnglishVariants = card.englishVariants.map {
                EnglishVariantInput(
                    id: $0.id,
                    text: $0.text,
                    ipa: $0.ipa,
                    partsOfSpeech: $0.partsOfSpeech,
                    usageExamples: $0.usageExamples.map {
                        UsageExampleInput(
                            id: $0.id,
                            text: $0.text,
                            partOfSpeech: $0.partOfSpeech
                        )
                    }
                )
            }
            initialSelectedTagIDs = Set(card.tags.map(\.id))
            initialAvailableTags = card.tags
        } else {
            initialRussianMeanings = [RussianMeaningInput()]
            initialEnglishVariants = [EnglishVariantInput()]
            initialSelectedTagIDs = []
            initialAvailableTags = []
        }

        russianMeanings = initialRussianMeanings
        englishVariants = initialEnglishVariants
        selectedTagIDs = initialSelectedTagIDs
        availableTags = initialAvailableTags
        expandedMetadataVariantIDs = Set(
            initialEnglishVariants.filter {
                !$0.ipa.isEmpty || !$0.partsOfSpeech.isEmpty || !$0.usageExamples.isEmpty
            }.map(\.id)
        )
        draftCardID = card?.id ?? UUID()
        initialContent = EditorContentSnapshot(
            russianMeanings: initialRussianMeanings,
            englishVariants: initialEnglishVariants,
            selectedTagIDs: initialSelectedTagIDs,
            newTagName: ""
        )
        for variant in initialEnglishVariants {
            ipaFieldStates[variant.id] = variant.ipa.isEmpty
                ? .empty
                : .userEdited(variant.ipa)
            partsOfSpeechFieldStates[variant.id] = variant.partsOfSpeech.isEmpty
                ? .empty
                : .userEdited(variant.partsOfSpeech)
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

    public var displayedValidationErrors: [CardDraft.ValidationError] {
        hasAttemptedSave ? validationErrors : []
    }

    public var isDirty: Bool {
        currentContent != initialContent
    }

    public var canDismissWithoutConfirmation: Bool {
        !isDirty || didSave || !isPresented
    }

    public func addRussianMeaning() {
        russianMeanings.append(RussianMeaningInput())
    }

    public func removeRussianMeaning(id: UUID) {
        russianMeanings.removeAll { $0.id == id }
    }

    public func addEnglishVariant() {
        let variant = EnglishVariantInput()
        englishVariants.append(variant)
        ipaFieldStates[variant.id] = .empty
        partsOfSpeechFieldStates[variant.id] = .empty
    }

    public func removeEnglishVariant(id: UUID) {
        lookupTasks[id]?.cancel()
        lookupTasks[id] = nil
        lookupRequestIDs[id] = nil
        lookupState[id] = nil
        pendingDictionarySuggestions[id] = nil
        ipaFieldStates[id] = nil
        partsOfSpeechFieldStates[id] = nil
        expandedMetadataVariantIDs.remove(id)
        englishVariants.removeAll { $0.id == id }
    }

    public func toggleMetadata(for variantID: UUID) {
        if expandedMetadataVariantIDs.contains(variantID) {
            expandedMetadataVariantIDs.remove(variantID)
        } else {
            expandedMetadataVariantIDs.insert(variantID)
        }
    }

    public func addUsageExample(variantID: UUID) {
        guard let index = englishVariants.firstIndex(where: { $0.id == variantID }),
              !englishVariants[index].partsOfSpeech.isEmpty else {
            return
        }

        let selectedPart = englishVariants[index].partsOfSpeech.count == 1
            ? englishVariants[index].partsOfSpeech.first
            : nil
        englishVariants[index].usageExamples.append(
            UsageExampleInput(partOfSpeech: selectedPart)
        )
    }

    public func removeUsageExample(id: UUID, variantID: UUID) {
        guard let index = englishVariants.firstIndex(where: { $0.id == variantID }) else {
            return
        }
        englishVariants[index].usageExamples.removeAll { $0.id == id }
    }

    public func chooseUsageExamplePartOfSpeech(
        _ partOfSpeech: PartOfSpeech,
        exampleID: UUID,
        variantID: UUID
    ) {
        guard let variantIndex = englishVariants.firstIndex(where: { $0.id == variantID }),
              englishVariants[variantIndex].partsOfSpeech.contains(partOfSpeech),
              let exampleIndex = englishVariants[variantIndex].usageExamples.firstIndex(
                where: { $0.id == exampleID }
              ) else {
            return
        }
        englishVariants[variantIndex].usageExamples[exampleIndex].partOfSpeech = partOfSpeech
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
            for exampleIndex in englishVariants[index].usageExamples.indices
            where englishVariants[index].usageExamples[exampleIndex].partOfSpeech == partOfSpeech {
                englishVariants[index].usageExamples[exampleIndex].partOfSpeech = nil
            }
        } else {
            englishVariants[index].partsOfSpeech.append(partOfSpeech)
        }
        markPartsOfSpeechUserEdited(variantID: variantID)
    }

    public func markIPAUserEdited(variantID: UUID) {
        guard let variant = englishVariants.first(where: { $0.id == variantID }) else { return }
        ipaFieldStates[variantID] = .userEdited(variant.ipa)
    }

    public func markPartsOfSpeechUserEdited(variantID: UUID) {
        guard let variant = englishVariants.first(where: { $0.id == variantID }) else { return }
        partsOfSpeechFieldStates[variantID] = .userEdited(variant.partsOfSpeech)
    }

    public func useDictionarySuggestion(variantID: UUID) {
        guard let suggestion = pendingDictionarySuggestions[variantID],
              let index = englishVariants.firstIndex(where: { $0.id == variantID }) else {
            return
        }

        if let ipa = suggestion.ipa?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ipa.isEmpty {
            englishVariants[index].ipa = ipa
            ipaFieldStates[variantID] = .suggested(ipa)
        }
        if let partOfSpeech = suggestion.partOfSpeech {
            let parts = [partOfSpeech]
            englishVariants[index].partsOfSpeech = parts
            partsOfSpeechFieldStates[variantID] = .suggested(parts)
        }
        pendingDictionarySuggestions[variantID] = nil
        lookupState[variantID] = .suggested
    }

    public func loadTags() async {
        do {
            let loadedTags = try await tagRepository.fetchTags()
            guard !Task.isCancelled else { return }

            // Keep tags selected or created while this load was in flight. The
            // repository can return a snapshot from before a newly created tag
            // was persisted, and replacing the catalog would otherwise drop it.
            let selectedTagsNotInLoadedCatalog = availableTags.filter {
                let existingTag = $0
                return selectedTagIDs.contains(existingTag.id)
                    && !loadedTags.contains(where: { loadedTag in loadedTag.id == existingTag.id })
            }
            availableTags = (loadedTags + selectedTagsNotInLoadedCatalog).reduce(into: []) { tags, tag in
                guard !tags.contains(where: { $0.id == tag.id }) else { return }
                tags.append(tag)
            }
            availableTags.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            selectedTagIDs.formIntersection(availableTags.map(\.id))
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
            availableTags.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
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
        guard !isSaving else { return .failed }
        hasAttemptedSave = true
        isSaving = true
        defer { isSaving = false }
        saveError = nil
        isDuplicateConfirmationPresented = false
        pendingDuplicateSaveSnapshot = nil
        let snapshot = saveSnapshot
        guard snapshot.draft.validationErrors.isEmpty else { return .invalid }

        do {
            let duplicates = try await cardRepository.duplicateCandidates(
                for: snapshot.draft,
                excluding: existingCard?.id
            )
            guard !Task.isCancelled else { return .failed }
            if !duplicates.isEmpty {
                pendingDuplicateSaveSnapshot = snapshot
                isDuplicateConfirmationPresented = true
                return .needsDuplicateConfirmation
            }
        } catch is CancellationError {
            return .failed
        } catch {
            saveError = .duplicateCheck
            return .failed
        }

        return await saveValidated(snapshot)
    }

    @discardableResult
    public func confirmDuplicateAndSave() async -> SaveOutcome {
        guard !isSaving else { return .failed }
        isSaving = true
        defer { isSaving = false }
        isDuplicateConfirmationPresented = false
        saveError = nil
        let snapshot = pendingDuplicateSaveSnapshot
        pendingDuplicateSaveSnapshot = nil
        let currentDraft = draft
        guard currentDraft.validationErrors.isEmpty else { return .invalid }
        guard let snapshot else { return .invalid }
        return await saveValidated(snapshot)
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

    public func speakUsageExample(id: UUID, variantID: UUID) {
        guard let variant = englishVariants.first(where: { $0.id == variantID }),
              let example = variant.usageExamples.first(where: { $0.id == id }) else {
            return
        }
        let text = example.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        speechService.speak(text)
    }

    public func cancel() {
        discardChanges()
    }

    public func discardChanges() {
        cancelLookupOperations()
        isPresented = false
    }

    public func cancelLookupOperations() {
        let tasks = Array(lookupTasks.values)
        lookupTasks.removeAll()
        lookupRequestIDs.removeAll()
        lookupState.removeAll()
        pendingDictionarySuggestions.removeAll()
        for task in tasks {
            task.cancel()
        }
    }

    private var draft: CardDraft {
        CardDraft(
            russianMeanings: russianMeanings.map(\.text),
            englishVariants: englishVariants.map {
                EnglishVariantDraft(
                    text: $0.text,
                    ipa: $0.ipa,
                    partsOfSpeech: $0.partsOfSpeech,
                    usageExamples: $0.usageExamples.map {
                        UsageExampleDraft(
                            text: $0.text,
                            partOfSpeech: $0.partOfSpeech
                        )
                    }
                )
            },
            tagIDs: availableTags
                .filter { selectedTagIDs.contains($0.id) }
                .map(\.id)
        )
    }

    private var saveSnapshot: SaveSnapshot {
        SaveSnapshot(
            draft: draft,
            russianMeaningIDs: russianMeanings.map(\.id),
            englishVariantIDs: englishVariants.map(\.id),
            usageExampleIDsByVariant: englishVariants.map { variant in
                variant.usageExamples.map(\.id)
            },
            resolvedTags: availableTags.filter { selectedTagIDs.contains($0.id) },
            cardID: draftCardID,
            createdAt: existingCard?.createdAt,
            timestamp: now()
        )
    }

    private func saveValidated(_ snapshot: SaveSnapshot) async -> SaveOutcome {
        do {
            let generatedCard = try snapshot.draft.makeCard(
                id: snapshot.cardID,
                russianMeaningIDs: snapshot.russianMeaningIDs,
                englishVariantIDs: snapshot.englishVariantIDs,
                usageExampleIDsByVariant: snapshot.usageExampleIDsByVariant,
                now: snapshot.timestamp
            )
            let card = VocabularyCard(
                id: generatedCard.id,
                russianMeanings: generatedCard.russianMeanings,
                englishVariants: generatedCard.englishVariants,
                tags: snapshot.resolvedTags,
                createdAt: snapshot.createdAt ?? generatedCard.createdAt,
                updatedAt: snapshot.timestamp,
                isLearned: existingCard?.isLearned ?? false
            )
            try await cardRepository.save(card)
            guard !Task.isCancelled else { return .failed }
            savedCard = card
            didSave = true
            isPresented = false
            return .saved
        } catch is CancellationError {
            return .failed
        } catch {
            saveError = .persistence
            return .failed
        }
    }

    private struct SaveSnapshot {
        let draft: CardDraft
        let russianMeaningIDs: [UUID]
        let englishVariantIDs: [UUID]
        let usageExampleIDsByVariant: [[UUID]]
        let resolvedTags: [Tag]
        let cardID: UUID
        let createdAt: Date?
        let timestamp: Date
    }

    private struct EditorContentSnapshot: Equatable {
        let russianMeanings: [RussianMeaningInput]
        let englishVariants: [EnglishVariantInput]
        let selectedTagIDs: Set<UUID>
        let newTagName: String
    }

    private var currentContent: EditorContentSnapshot {
        EditorContentSnapshot(
            russianMeanings: russianMeanings,
            englishVariants: englishVariants,
            selectedTagIDs: selectedTagIDs,
            newTagName: newTagName
        )
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

        let lookupSleep = self.lookupSleep
        let task = Task { [weak self, lookupSleep] in
            if let debounce {
                do {
                    try await lookupSleep(debounce)
                } catch {
                    return
                }
            }

            guard !Task.isCancelled,
                  let self,
                  self.isCurrentLookup(
                    variantID: variantID,
                    requestID: requestID,
                    text: text
                  ) else {
                return
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

            synchronizeDictionaryFieldStates(for: variantID, at: index)
            var appliedSuggestion = false
            var hasConflict = false
            if let ipa = suggestion.ipa?.trimmingCharacters(in: .whitespacesAndNewlines),
               !ipa.isEmpty {
                switch ipaFieldStates[variantID] ?? .empty {
                case .empty, .suggested:
                    englishVariants[index].ipa = ipa
                    ipaFieldStates[variantID] = .suggested(ipa)
                    appliedSuggestion = true
                case let .userEdited(value):
                    hasConflict = hasConflict || value != ipa
                }
            }
            if let partOfSpeech = suggestion.partOfSpeech {
                let parts = [partOfSpeech]
                switch partsOfSpeechFieldStates[variantID] ?? .empty {
                case .empty, .suggested:
                    englishVariants[index].partsOfSpeech = parts
                    partsOfSpeechFieldStates[variantID] = .suggested(parts)
                    appliedSuggestion = true
                case let .userEdited(value):
                    hasConflict = hasConflict || value != parts
                }
            }
            if hasConflict {
                pendingDictionarySuggestions[variantID] = suggestion
                lookupState[variantID] = .conflict
            } else {
                pendingDictionarySuggestions[variantID] = nil
                lookupState[variantID] = appliedSuggestion ? .suggested : .notFound
            }
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

    private func synchronizeDictionaryFieldStates(for variantID: UUID, at index: Int) {
        let ipa = englishVariants[index].ipa
        switch ipaFieldStates[variantID] {
        case .none, .some(.empty):
            ipaFieldStates[variantID] = ipa.isEmpty ? .empty : .userEdited(ipa)
        case let .some(.suggested(value)) where value != ipa:
            ipaFieldStates[variantID] = .userEdited(ipa)
        case let .some(.userEdited(value)) where value != ipa:
            ipaFieldStates[variantID] = .userEdited(ipa)
        default:
            break
        }

        let parts = englishVariants[index].partsOfSpeech
        switch partsOfSpeechFieldStates[variantID] {
        case .none, .some(.empty):
            partsOfSpeechFieldStates[variantID] = parts.isEmpty ? .empty : .userEdited(parts)
        case let .some(.suggested(value)) where value != parts:
            partsOfSpeechFieldStates[variantID] = .userEdited(parts)
        case let .some(.userEdited(value)) where value != parts:
            partsOfSpeechFieldStates[variantID] = .userEdited(parts)
        default:
            break
        }
    }
}
