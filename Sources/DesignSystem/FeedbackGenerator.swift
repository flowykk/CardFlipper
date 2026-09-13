import UIKit

public enum FeedbackAction {
    @MainActor
    public static func perform(
        feedback: () -> Void,
        action: () -> Void
    ) {
        feedback()
        action()
    }
}

public enum HapticButtonFeedback: Sendable {
    case tap
    case selection
    case none

    @MainActor
    func perform() {
        switch self {
        case .tap:
            FeedbackGenerator.shared.tap()
        case .selection:
            FeedbackGenerator.shared.selection()
        case .none:
            break
        }
    }
}

@MainActor
public final class FeedbackGenerator {
    public static let shared = FeedbackGenerator()

    private let flipGenerator = UIImpactFeedbackGenerator(style: .light)
    private let tapGenerator = UIImpactFeedbackGenerator(style: .light)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    public func tap() {
        tapGenerator.impactOccurred(intensity: 0.7)
        tapGenerator.prepare()
    }

    public func flip() {
        flipGenerator.impactOccurred()
        flipGenerator.prepare()
    }

    public func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    public func successfulSave() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    public func remember() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    public func forget() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
}
