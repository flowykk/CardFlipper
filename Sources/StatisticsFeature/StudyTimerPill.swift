import SwiftUI

public struct StudyTimerPill: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let snapshot: StudyTimerSnapshot

    public init(snapshot: StudyTimerSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Label {
                    Text(verbatim: StudyDurationFormatter.string(seconds: snapshot.sessionElapsedSeconds))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.subheadline.weight(.semibold))
            } else {
                Label {
                    Text(verbatim: StudyTimerCopy.summary(snapshot))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "timer")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: StudyTimerCopy.summary(snapshot)))
        .accessibilityIdentifier("study.timer")
    }
}
