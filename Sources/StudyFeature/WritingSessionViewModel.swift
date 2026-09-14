import Core
import Foundation
import Observation

@MainActor
@Observable
public final class WritingSessionViewModel {
    public private(set) var session: WritingSession
    public private(set) var result: StudyResult?
    public private(set) var isShowingUsageExamples = false
    public var isExitConfirmationPresented = false

    public private(set) var repeatConfiguration: StudyConfiguration

    private let sessionID: UUID
    private let originalSelectedTagNames: [String]
    private let originalCardIDs: [UUID]
    private let originalCardDisplaySnapshots: [StudyCardDisplaySnapshot]
    private let speech: any SpeechService
    private let feedback: any StudyFeedback
    private let store: (any StudySessionStore)?
    private let now: @MainActor () -> Date
    private let sessionStartedAt: Date
    private var editingStartedAt: Date?
    private var editingDuration: TimeInterval = 0
    private let segmentStartedAt: Date
    private let accumulatedDurationAtStart: Int
    private let initialDailyGoalProgress: StudyDailyGoalProgress?

    public init(
        configuration: StudyConfiguration,
        sessionID: UUID,
        selectedTagNames: [String],
        snapshot: StudySessionSnapshot? = nil,
        shuffler: any CardShuffler = SystemCardShuffler(),
        speech: any SpeechService,
        feedback: any StudyFeedback = SystemStudyFeedback(),
        initialDailyGoalProgress: StudyDailyGoalProgress? = nil,
        store: (any StudySessionStore)? = nil,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        let originalSelectedTagNames = snapshot?.selectedTagNames ?? selectedTagNames
        repeatConfiguration = StudyConfiguration(
            mode: configuration.mode,
            direction: configuration.direction,
            selectedTagIDs: configuration.selectedTagIDs,
            selectedTagNames: originalSelectedTagNames,
            cards: configuration.cards
        )
        self.sessionID = snapshot?.sessionID ?? sessionID
        self.originalSelectedTagNames = originalSelectedTagNames
        originalCardIDs = snapshot?.originalCardIDs ?? configuration.cards.map(\.id)
        originalCardDisplaySnapshots = snapshot?.cardDisplaySnapshots
            ?? configuration.cards.map {
                StudyCardDisplaySnapshot(id: $0.id, title: studyCardDisplayTitle($0))
            }
        let initializationDate = now()
        if let snapshot {
            let cardsByID = Dictionary(uniqueKeysWithValues: configuration.cards.map { ($0.id, $0) })
            let queue = snapshot.queueCardIDs.compactMap { cardsByID[$0] }
            let restoresCurrentCard = queue.first?.id == snapshot.queueCardIDs.first
            session = WritingSession(
                cards: queue,
                initialCardCount: snapshot.originalCardIDs.count,
                response: restoresCurrentCard ? snapshot.writingResponse : "",
                evaluation: restoresCurrentCard ? snapshot.writingEvaluation : .unanswered,
                isShowingAnswer: restoresCurrentCard && snapshot.isShowingAnswer,
                hasRevealedAnswer: restoresCurrentCard && snapshot.isRevealed,
                forgottenCount: snapshot.forgottenCount,
                encounteredCardIDs: snapshot.encounteredCardIDs,
                completedCardIDs: snapshot.completedCardIDs,
                repeatedCardIDs: snapshot.repeatedCardIDs,
                totalAssessmentCount: snapshot.totalAssessmentCount
            )
            result = snapshot.completedResult
            accumulatedDurationAtStart = snapshot.accumulatedDurationSeconds
            sessionStartedAt = snapshot.startedAt
        } else {
            session = WritingSession(cards: shuffler.shuffle(configuration.cards))
            accumulatedDurationAtStart = 0
            sessionStartedAt = initializationDate
        }
        self.speech = speech
        self.feedback = feedback
        self.store = store
        self.initialDailyGoalProgress = initialDailyGoalProgress
        self.now = now
        segmentStartedAt = initializationDate
        persistSnapshot()
    }

    public convenience init(
        configuration: StudyConfiguration,
        snapshot: StudySessionSnapshot? = nil,
        shuffler: any CardShuffler = SystemCardShuffler(),
        speech: any SpeechService,
        feedback: any StudyFeedback = SystemStudyFeedback(),
        initialDailyGoalProgress: StudyDailyGoalProgress? = nil,
        store: (any StudySessionStore)? = nil,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.init(
            configuration: configuration,
            sessionID: UUID(),
            selectedTagNames: configuration.selectedTagNames,
            snapshot: snapshot,
            shuffler: shuffler,
            speech: speech,
            feedback: feedback,
            initialDailyGoalProgress: initialDailyGoalProgress,
            store: store,
            now: now
        )
    }

    public var response: String { session.response }
    public var evaluation: WritingAnswerEvaluation { session.evaluation }
    public var isShowingAnswer: Bool { session.isShowingAnswer }
    public var canCheck: Bool {
        !TextNormalizer.searchKey(response).isEmpty
            && evaluation != .correct
            && !session.isComplete
    }
    public var canAssess: Bool { evaluation == .correct && !session.isComplete }
    public var progressPresentation: StudySessionProgressPresentation {
        StudySessionProgressPresentation(
            rememberedCount: session.completedCardIDs.count,
            totalCount: session.initialCardCount
        )
    }
    public var hasUsageExamples: Bool {
        session.currentCard?.englishVariants.contains { !$0.usageExamples.isEmpty } == true
    }
    public var difficultCards: [VocabularyCard] {
        let repeatedIDs = Set(session.repeatedCardIDs)
        return repeatConfiguration.cards.filter { repeatedIDs.contains($0.id) }
    }
    public var difficultRepeatConfiguration: StudyConfiguration? {
        guard !difficultCards.isEmpty else { return nil }
        return StudyConfiguration(
            mode: .writing,
            direction: .russianToEnglish,
            selectedTagIDs: repeatConfiguration.selectedTagIDs,
            selectedTagNames: originalSelectedTagNames,
            cards: difficultCards
        )
    }
    public var dailyGoalProgress: StudyDailyGoalProgress? {
        guard let initialDailyGoalProgress else { return nil }
        return StudyDailyGoalProgress(
            elapsedSeconds: initialDailyGoalProgress.elapsedSeconds + (result?.elapsedSeconds ?? 0),
            goalSeconds: initialDailyGoalProgress.goalSeconds
        )
    }

    public func setResponse(_ response: String) {
        session.setResponse(response)
        persistSnapshot()
    }

    public func checkResponse() {
        guard canCheck else { return }
        let evaluation = session.checkResponse()
        feedback.perform(evaluation == .correct ? .remember : .forget)
        persistSnapshot()
    }

    public func toggleAnswer() {
        guard !session.isComplete else { return }
        session.toggleAnswer()
        if !session.isShowingAnswer {
            isShowingUsageExamples = false
        }
        feedback.perform(.reveal)
        persistSnapshot()
    }

    public func toggleUsageExamples() {
        guard isShowingAnswer, hasUsageExamples else { return }
        isShowingUsageExamples.toggle()
    }

    public func remember() throws {
        try session.remember()
        isShowingUsageExamples = false
        if session.isComplete {
            result = StudyResult(
                plannedCardCount: session.initialCardCount,
                completedCardCount: session.completedCardIDs.count,
                encounteredCardIDs: session.encounteredCardIDs,
                repeatedCardIDs: session.repeatedCardIDs,
                totalAssessmentCount: session.totalAssessmentCount,
                elapsedSeconds: elapsedSeconds,
                forgottenCount: session.forgottenCount
            )
            feedback.perform(.completion)
        }
        persistSnapshot()
    }

    public func forget() throws {
        try session.forget()
        isShowingUsageExamples = false
        feedback.perform(.forget)
        persistSnapshot()
    }

    public func speakEnglish(variantID: UUID) {
        guard let variant = session.currentCard?.englishVariants.first(where: { $0.id == variantID })
        else { return }
        speech.speak(variant.text)
    }

    public func speakUsageExample(variantID: UUID, exampleID: UUID) {
        guard isShowingAnswer,
              isShowingUsageExamples,
              let variant = session.currentCard?.englishVariants.first(where: { $0.id == variantID }),
              let example = variant.usageExamples.first(where: { $0.id == exampleID })
        else { return }
        speech.speak(example.text)
    }

    public var canEditCard: Bool { isShowingAnswer && !session.isComplete && result == nil }

    public func setEditing(_ isEditing: Bool) {
        if isEditing {
            guard editingStartedAt == nil else { return }
            editingStartedAt = now()
        } else if let startedAt = editingStartedAt {
            editingDuration += max(0, now().timeIntervalSince(startedAt))
            editingStartedAt = nil
        }
        persistSnapshot()
    }

    public func applyEditedCard(_ card: VocabularyCard) {
        session.updateCard(card)
        repeatConfiguration = StudyConfiguration(
            mode: repeatConfiguration.mode,
            direction: repeatConfiguration.direction,
            selectedTagIDs: repeatConfiguration.selectedTagIDs,
            selectedTagNames: repeatConfiguration.selectedTagNames,
            cards: repeatConfiguration.cards.map { $0.id == card.id ? card : $0 }
        )
        persistSnapshot()
    }

    public func requestExit() {
        isExitConfirmationPresented = true
    }

    public func cancelExit() {
        isExitConfirmationPresented = false
    }

    public func persistSnapshot() {
        let activityDate = now()
        store?.save(StudySessionSnapshot(
            mode: .writing,
            direction: .russianToEnglish,
            selectedTagIDs: repeatConfiguration.selectedTagIDs,
            originalCardIDs: originalCardIDs,
            queueCardIDs: session.queue.map(\.id),
            isShowingAnswer: session.isShowingAnswer,
            isRevealed: session.hasRevealedAnswer,
            forgottenCount: session.forgottenCount,
            repeatedCardIDs: session.repeatedCardIDs,
            totalAssessmentCount: session.totalAssessmentCount,
            writingResponse: session.response,
            writingEvaluation: session.evaluation,
            startedAt: sessionStartedAt,
            accumulatedDurationSeconds: result?.elapsedSeconds ?? elapsedSeconds(at: activityDate),
            sessionID: sessionID,
            lastActivityAt: activityDate,
            encounteredCardIDs: session.encounteredCardIDs,
            completedCardIDs: session.completedCardIDs,
            selectedTagNames: originalSelectedTagNames,
            cardDisplaySnapshots: originalCardDisplaySnapshots,
            completedResult: result
        ))
    }

    private var elapsedSeconds: Int {
        elapsedSeconds(at: now())
    }

    private func elapsedSeconds(at activityDate: Date) -> Int {
        accumulatedDurationAtStart
            + max(0, Int(((editingStartedAt ?? activityDate).timeIntervalSince(segmentStartedAt) - editingDuration).rounded(.down)))
    }
}
