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

    public let repeatConfiguration: StudyConfiguration

    private let speech: any SpeechService
    private let feedback: any StudyFeedback
    private let store: (any StudySessionStore)?
    private let now: @MainActor () -> Date
    private let sessionStartedAt: Date
    private let segmentStartedAt: Date
    private let accumulatedDurationAtStart: Int
    private let initialDailyGoalProgress: StudyDailyGoalProgress?

    public init(
        configuration: StudyConfiguration,
        snapshot: StudySessionSnapshot? = nil,
        shuffler: any CardShuffler = SystemCardShuffler(),
        speech: any SpeechService,
        feedback: any StudyFeedback = SystemStudyFeedback(),
        initialDailyGoalProgress: StudyDailyGoalProgress? = nil,
        store: (any StudySessionStore)? = nil,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        repeatConfiguration = configuration
        let initializationDate = now()
        if let snapshot {
            let cardsByID = Dictionary(uniqueKeysWithValues: configuration.cards.map { ($0.id, $0) })
            let queue = snapshot.queueCardIDs.compactMap { cardsByID[$0] }
            session = WritingSession(
                cards: queue,
                initialCardCount: configuration.cards.count,
                response: snapshot.writingResponse,
                evaluation: snapshot.writingEvaluation,
                isShowingAnswer: snapshot.isShowingAnswer,
                hasRevealedAnswer: snapshot.isRevealed,
                forgottenCount: snapshot.forgottenCount,
                repeatedCardIDs: snapshot.repeatedCardIDs.filter { cardsByID[$0] != nil },
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
            rememberedCount: session.initialCardCount - session.remainingCount,
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
                reviewedCardCount: session.initialCardCount,
                repeatedCardIDs: session.repeatedCardIDs,
                totalAssessmentCount: session.totalAssessmentCount,
                elapsedSeconds: elapsedSeconds
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
        guard isShowingAnswer,
              let variant = session.currentCard?.englishVariants.first(where: { $0.id == variantID })
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

    public func requestExit() {
        isExitConfirmationPresented = true
    }

    public func cancelExit() {
        isExitConfirmationPresented = false
    }

    public func persistSnapshot() {
        store?.save(StudySessionSnapshot(
            mode: .writing,
            direction: .russianToEnglish,
            selectedTagIDs: repeatConfiguration.selectedTagIDs,
            originalCardIDs: repeatConfiguration.cards.map(\.id),
            queueCardIDs: session.queue.map(\.id),
            isShowingAnswer: session.isShowingAnswer,
            isRevealed: session.hasRevealedAnswer,
            forgottenCount: session.forgottenCount,
            repeatedCardIDs: session.repeatedCardIDs,
            totalAssessmentCount: session.totalAssessmentCount,
            writingResponse: session.response,
            writingEvaluation: session.evaluation,
            startedAt: sessionStartedAt,
            accumulatedDurationSeconds: result?.elapsedSeconds ?? elapsedSeconds,
            completedResult: result
        ))
    }

    private var elapsedSeconds: Int {
        accumulatedDurationAtStart
            + max(0, Int(now().timeIntervalSince(segmentStartedAt).rounded(.down)))
    }
}
