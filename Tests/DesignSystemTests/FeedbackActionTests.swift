import SwiftUI
import Testing
@testable import DesignSystem

@MainActor
@Test func feedbackActionPerformsFeedbackBeforeAction() {
    var events: [String] = []

    FeedbackAction.perform(
        feedback: { events.append("feedback") },
        action: { events.append("action") }
    )

    #expect(events == ["feedback", "action"])
}

@MainActor
@Test func feedbackBindingPerformsFeedbackOnlyWhenControlSetsValue() {
    var value = 0
    var events: [String] = []
    let source = Binding(
        get: { value },
        set: {
            value = $0
            events.append("set")
        }
    )
    let feedbackBinding = source.withFeedback {
        events.append("feedback")
    }

    value = 1
    #expect(events.isEmpty)

    feedbackBinding.wrappedValue = 2
    #expect(value == 2)
    #expect(events == ["feedback", "set"])
}
