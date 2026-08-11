import SwiftUI

public struct StudyTimerPill: View {
    private let snapshot: StudyTimerSnapshot

    public init(snapshot: StudyTimerSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Label {
            Text("\(StudyDurationFormatter.string(seconds: snapshot.todayElapsedSeconds)) / +\(StudyDurationFormatter.string(seconds: snapshot.sessionElapsedSeconds))")
                .font(.system(.headline, design: .monospaced, weight: .semibold))
                .monospacedDigit()
        } icon: {
            Image(systemName: "timer")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today \(StudyDurationFormatter.string(seconds: snapshot.todayElapsedSeconds)). Current session \(StudyDurationFormatter.string(seconds: snapshot.sessionElapsedSeconds)).")
        .accessibilityIdentifier("study.timer")
    }
}
