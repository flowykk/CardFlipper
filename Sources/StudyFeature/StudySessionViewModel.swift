import Core
import DesignSystem
import Foundation
import Observation

public enum StudyFeedbackEvent: Equatable, Sendable {
    case reveal
    case remember
    case forget
    case completion
}

public struct StudyDailyGoalProgress: Equatable, Sendable {
    public let elapsedSeconds: Int
    public let goalSeconds: Int

    public init(elapsedSeconds: Int, goalSeconds: Int) {
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.goalSeconds = max(1, goalSeconds)
    }

    public var fractionCompleted: Double {
        min(1, Double(elapsedSeconds) / Double(goalSeconds))
    }
}

@MainActor
public protocol StudyFeedback: AnyObject {
    func perform(_ event: StudyFeedbackEvent)
}

@MainActor
public final class SystemStudyFeedback: StudyFeedback {
    public init() {}

    public func perform(_ event: StudyFeedbackEvent) {
        switch event {
        case .reveal:
            FeedbackGenerator.shared.flip()
        case .remember, .completion:
            FeedbackGenerator.shared.remember()
        case .forget:
            FeedbackGenerator.shared.forget()
        }
    }
}

@MainActor
@Observable
public final class StudySessionViewModel {
    public private(set) var session: StudySession
    public private(set) var result: StudyResult?
    public private(set) var isShowingAnswer = false
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
            session = StudySession(
                cards: queue,
                direction: snapshot.direction,
                initialCardCount: configuration.cards.count,
                forgottenCount: snapshot.forgottenCount,
                repeatedCardIDs: snapshot.repeatedCardIDs.filter { cardsByID[$0] != nil },
                totalAssessmentCount: snapshot.totalAssessmentCount,
                isRevealed: snapshot.isRevealed
            )
            isShowingAnswer = snapshot.isShowingAnswer && !queue.isEmpty
            result = snapshot.completedResult
            accumulatedDurationAtStart = snapshot.accumulatedDurationSeconds
            sessionStartedAt = snapshot.startedAt
        } else {
            session = StudySession(
                cards: shuffler.shuffle(configuration.cards),
                direction: configuration.direction
            )
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

    public var canAssess: Bool {
        session.isRevealed && !session.isComplete
    }

    public var rememberedCount: Int {
        session.initialCardCount - session.remainingCount
    }

    public var hasUsageExamples: Bool {
        session.currentCard?.englishVariants.contains { !$0.usageExamples.isEmpty } == true
    }

    public var difficultCards: [VocabularyCard] {
        guard let result else { return [] }
        let repeatedIDs = Set(result.repeatedCardIDs)
        return repeatConfiguration.cards.filter { repeatedIDs.contains($0.id) }
    }

    public var difficultRepeatConfiguration: StudyConfiguration? {
        guard !difficultCards.isEmpty else { return nil }
        return StudyConfiguration(
            direction: repeatConfiguration.direction,
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

    public func toggleCardSide() {
        guard !session.isComplete else { return }

        if !session.isRevealed {
            session.reveal()
        }

        isShowingAnswer.toggle()
        feedback.perform(.reveal)
        persistSnapshot()
    }

    public func toggleUsageExamples() {
        guard canAssess, hasUsageExamples else { return }
        isShowingUsageExamples.toggle()
    }

    public func remember() throws {
        try session.remember()
        isShowingAnswer = false
        isShowingUsageExamples = false

        if session.isComplete {
            result = StudyResult(
                reviewedCardCount: session.initialCardCount,
                repeatedCardIDs: session.repeatedCardIDs,
                totalAssessmentCount: session.totalAssessmentCount,
                elapsedSeconds: elapsedSeconds
            )
            feedback.perform(.completion)
        } else {
            feedback.perform(.remember)
        }
        persistSnapshot()
    }

    public func forget() throws {
        try session.forget()
        isShowingAnswer = false
        isShowingUsageExamples = false
        feedback.perform(.forget)
        persistSnapshot()
    }

    public func speakEnglish(variantID: UUID) {
        guard isEnglishSideVisible,
              let variant = session.currentCard?.englishVariants.first(where: { $0.id == variantID })
        else {
            return
        }

        speech.speak(variant.text)
    }

    public func speakUsageExample(variantID: UUID, exampleID: UUID) {
        guard canAssess,
              isShowingUsageExamples,
              let variant = session.currentCard?.englishVariants.first(
                where: { $0.id == variantID }
              ),
              let example = variant.usageExamples.first(where: { $0.id == exampleID }) else {
            return
        }

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
            direction: session.direction,
            selectedTagIDs: repeatConfiguration.selectedTagIDs,
            originalCardIDs: repeatConfiguration.cards.map(\.id),
            queueCardIDs: session.queue.map(\.id),
            isShowingAnswer: isShowingAnswer,
            isRevealed: session.isRevealed,
            forgottenCount: session.forgottenCount,
            repeatedCardIDs: session.repeatedCardIDs,
            totalAssessmentCount: session.totalAssessmentCount,
            startedAt: sessionStartedAt,
            accumulatedDurationSeconds: result?.elapsedSeconds ?? elapsedSeconds,
            completedResult: result
        ))
    }

    private var elapsedSeconds: Int {
        accumulatedDurationAtStart
            + max(0, Int(now().timeIntervalSince(segmentStartedAt).rounded(.down)))
    }

    private var isEnglishSideVisible: Bool {
        switch session.direction {
        case .russianToEnglish:
            isShowingAnswer
        case .englishToRussian:
            !isShowingAnswer
        }
    }
}
