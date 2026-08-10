import UIKit

@MainActor
public final class FeedbackGenerator {
    public static let shared = FeedbackGenerator()

    private let flipGenerator = UIImpactFeedbackGenerator(style: .light)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    public func flip() {
        flipGenerator.impactOccurred()
        flipGenerator.prepare()
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
