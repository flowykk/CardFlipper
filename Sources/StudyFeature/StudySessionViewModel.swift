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
    public var isExitConfirmationPresented = false

    public let repeatConfiguration: StudyConfiguration

    private let speech: any SpeechService
    private let feedback: any StudyFeedback

    public init(
        configuration: StudyConfiguration,
        shuffler: any CardShuffler = SystemCardShuffler(),
        speech: any SpeechService,
        feedback: any StudyFeedback = SystemStudyFeedback()
    ) {
        repeatConfiguration = configuration
        session = StudySession(
            cards: shuffler.shuffle(configuration.cards),
            direction: configuration.direction
        )
        self.speech = speech
        self.feedback = feedback
    }

    public var canAssess: Bool {
        session.isRevealed && !session.isComplete
    }

    public var rememberedCount: Int {
        session.initialCardCount - session.remainingCount
    }

    public func reveal() {
        guard !session.isComplete, !session.isRevealed else { return }
        session.reveal()
        feedback.perform(.reveal)
    }

    public func remember() throws {
        try session.remember()

        if session.isComplete {
            result = StudyResult(
                uniqueCardCount: session.initialCardCount,
                forgottenCount: session.forgottenCount
            )
            feedback.perform(.completion)
        } else {
            feedback.perform(.remember)
        }
    }

    public func forget() throws {
        try session.forget()
        feedback.perform(.forget)
    }

    public func speakEnglish(variantID: UUID) {
        guard isEnglishSideVisible,
              let variant = session.currentCard?.englishVariants.first(where: { $0.id == variantID })
        else {
            return
        }

        speech.speak(variant.text)
    }

    public func requestExit() {
        isExitConfirmationPresented = true
    }

    public func cancelExit() {
        isExitConfirmationPresented = false
    }

    private var isEnglishSideVisible: Bool {
        switch session.direction {
        case .russianToEnglish:
            session.isRevealed
        case .englishToRussian:
            !session.isRevealed
        }
    }
}
