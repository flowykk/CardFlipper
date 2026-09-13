import SwiftUI

public struct HapticButton<Label: View>: View {
    private let feedback: HapticButtonFeedback
    private let role: ButtonRole?
    private let action: () -> Void
    private let label: () -> Label

    public init(
        feedback: HapticButtonFeedback = .tap,
        role: ButtonRole? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.feedback = feedback
        self.role = role
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(role: role) {
            FeedbackAction.perform(
                feedback: feedback.perform,
                action: action
            )
        } label: {
            label()
        }
    }
}

public extension HapticButton where Label == Text {
    init(
        _ titleKey: LocalizedStringKey,
        feedback: HapticButtonFeedback = .tap,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.init(feedback: feedback, role: role, action: action) {
            Text(titleKey)
        }
    }
}

public extension Binding {
    @MainActor
    func withFeedback(_ feedback: @escaping () -> Void) -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                FeedbackAction.perform(
                    feedback: feedback,
                    action: { wrappedValue = newValue }
                )
            }
        )
    }

    @MainActor
    func withSelectionFeedback() -> Binding<Value> {
        withFeedback(FeedbackGenerator.shared.selection)
    }
}

public extension Binding where Value: Collection {
    @MainActor
    func withBackNavigationFeedback() -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                if newValue.count < wrappedValue.count {
                    FeedbackGenerator.shared.tap()
                }
                wrappedValue = newValue
            }
        )
    }
}
