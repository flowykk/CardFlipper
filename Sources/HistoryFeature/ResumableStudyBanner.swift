import Core
import DesignSystem
import Foundation
import SwiftUI

public struct ResumableStudyBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.self) private var environment

    private let snapshot: StudySessionSnapshot
    private let onResume: () -> Void

    public init(snapshot: StudySessionSnapshot, onResume: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onResume = onResume
    }

    public var body: some View {
        HapticButton(action: onResume) {
            MetricTable(backgroundStyle: Color.accentColor) {
                MetricTableRow(systemImage: modeSystemImage, iconColor: foregroundColor) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: HistoryPresentation.dateTime(snapshot.lastActivityAt))
                            .font(.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text(verbatim: progress)
                            .font(.caption)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                } trailing: {
                    continueText
                }
            }
            .foregroundStyle(foregroundColor)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel([mode, progress, lastActivity, continueTitle].joined(separator: ", "))
        .accessibilityIdentifier("study.resume.banner")
    }

    private var foregroundColor: Color {
        let resolvedAccent = Color(Color.accentColor.resolve(in: environment))
        return AccessibleAccent.preferredForegroundColor(over: resolvedAccent, scheme: colorScheme)
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

    private var modeSystemImage: String {
        switch snapshot.mode {
        case .flashcards:
            "rectangle.stack.fill"
        case .writing:
            "keyboard.fill"
        }
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
