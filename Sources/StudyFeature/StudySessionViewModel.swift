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

public struct StudySessionProgressPresentation: Equatable, Sendable {
    public let positionText: String
    public let fractionCompleted: Double

    public init(rememberedCount: Int, totalCount: Int) {
        let total = max(0, totalCount)
        let position = total == 0
            ? 0
            : min(max(rememberedCount + 1, 1), total)

        positionText = "\(position)/\(total)"
        fractionCompleted = total == 0
            ? 0
            : Double(position) / Double(total)
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

    private let sessionID: UUID
    private let originalSelectedTagNames: [String]
    private let originalCardIDs: [UUID]
    private let originalCardDisplaySnapshots: [StudyCardDisplaySnapshot]
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
            session = StudySession(
                cards: queue,
                direction: snapshot.direction,
                initialCardCount: snapshot.originalCardIDs.count,
                forgottenCount: snapshot.forgottenCount,
                encounteredCardIDs: snapshot.encounteredCardIDs,
                completedCardIDs: snapshot.completedCardIDs,
                repeatedCardIDs: snapshot.repeatedCardIDs,
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

    public var canAssess: Bool {
        session.isRevealed && !session.isComplete
    }

    public var rememberedCount: Int {
        session.completedCardIDs.count
    }

    public var progressPresentation: StudySessionProgressPresentation {
        StudySessionProgressPresentation(
            rememberedCount: rememberedCount,
            totalCount: session.initialCardCount
        )
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
            mode: repeatConfiguration.mode,
            direction: repeatConfiguration.direction,
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
                plannedCardCount: session.initialCardCount,
                completedCardCount: session.completedCardIDs.count,
                encounteredCardIDs: session.encounteredCardIDs,
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
        let activityDate = now()
        store?.save(StudySessionSnapshot(
            mode: repeatConfiguration.mode,
            direction: session.direction,
            selectedTagIDs: repeatConfiguration.selectedTagIDs,
            originalCardIDs: originalCardIDs,
            queueCardIDs: session.queue.map(\.id),
            isShowingAnswer: isShowingAnswer,
            isRevealed: session.isRevealed,
            forgottenCount: session.forgottenCount,
            repeatedCardIDs: session.repeatedCardIDs,
            totalAssessmentCount: session.totalAssessmentCount,
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
            + max(0, Int(activityDate.timeIntervalSince(segmentStartedAt).rounded(.down)))
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
