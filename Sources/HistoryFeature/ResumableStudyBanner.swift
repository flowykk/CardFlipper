import Core
import DesignSystem
import Foundation
import SwiftUI

public struct ResumableStudyBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    private let snapshot: StudySessionSnapshot
    private let onResume: () -> Void

    public init(snapshot: StudySessionSnapshot, onResume: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onResume = onResume
    }

    public var body: some View {
        HapticButton(action: onResume) {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        modeText
                        Spacer(minLength: 8)
                        continueText
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        modeText
                        continueText
                    }
                }

                Text(verbatim: progress)
                    .font(.subheadline)
                    .monospacedDigit()

                Text(verbatim: lastActivity)
                    .font(.footnote)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding()
            .foregroundStyle(foregroundColor)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([mode, progress, lastActivity, continueTitle].joined(separator: ", "))
        .accessibilityIdentifier("study.resume.banner")
    }

    private var foregroundColor: Color {
        AccessibleAccent.preferredForegroundColor(over: .accentColor, scheme: colorScheme)
    }

    private var modeText: some View {
        Text(verbatim: mode)
            .font(.headline)
    }

    private var continueText: some View {
        HStack(spacing: 5) {
            Text(verbatim: continueTitle)
                .font(.headline)
            Image(systemName: "chevron.forward")
                .font(.subheadline.weight(.semibold))
                .accessibilityHidden(true)
        }
    }

    private var mode: String {
        HistoryPresentation.mode(snapshot.mode)
    }

    private var progress: String {
        let total = snapshot.originalCardIDs.count
        let completed = min(total, snapshot.completedCardIDs.count)
        return HistoryPresentation.progress(completed: completed, total: total)
    }

    private var continueTitle: String {
        HistoryLocalization.string("history.continue")
    }

    private var lastActivity: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeDate = formatter.localizedString(
            for: snapshot.lastActivityAt,
            relativeTo: Date()
        )
        return HistoryLocalization.format("history.lastActivity.format", relativeDate)
    }
}
