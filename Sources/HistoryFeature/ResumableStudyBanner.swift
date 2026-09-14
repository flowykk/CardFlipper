import Core
import DesignSystem
import Foundation
import SwiftUI

public struct ResumableStudyBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0
    @State private var bannerWidth: CGFloat = 0
    @State private var bannerHeight: CGFloat = 0
    @State private var collapseProgress: CGFloat = 0
    @State private var isDismissing = false
    @State private var hasAppeared = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.self) private var environment

    private let snapshot: StudySessionSnapshot
    private let onResume: () -> Void
    private let onHide: (() -> Void)?
    private let verticalPadding: CGFloat

    public init(
        snapshot: StudySessionSnapshot,
        onResume: @escaping () -> Void,
        onHide: (() -> Void)? = nil,
        verticalPadding: CGFloat = 0
    ) {
        self.snapshot = snapshot
        self.onResume = onResume
        self.onHide = onHide
        self.verticalPadding = verticalPadding
    }

    public var body: some View {
        if let onHide {
            banner
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, verticalPadding)
                .offset(x: dragOffset)
                .opacity(isDismissing ? 0 : 1)
                .allowsHitTesting(!isDismissing)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { size in
                    bannerWidth = size.width
                    bannerHeight = size.height
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard !isDismissing else { return }
                            if abs(value.translation.width) > abs(value.translation.height) {
                                let translation = value.translation.width
                                dragOffset = translation < 0 ? translation : translation * 0.2
                            }
                        }
                        .onEnded { value in
                            guard !isDismissing else { return }
                            if value.translation.width < -120,
                               abs(value.translation.width) > abs(value.translation.height) {
                                dismissBanner(onHide)
                            } else {
                                withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.55, bounce: 0.5)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .modifier(ResumeBannerCollapse(height: bannerHeight, progress: collapseProgress))
                .accessibilityAction(named: Text("history.resume.hide", bundle: .module)) {
                    dismissBanner(onHide)
                }
        } else {
            banner
        }
    }

    private var banner: some View {
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
        .scaleEffect(reduceMotion || hasAppeared ? 1 : 0.93)
        .offset(y: reduceMotion || hasAppeared ? 0 : -16)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.45)) {
                hasAppeared = true
            }
        }
    }

    private func dismissBanner(_ onHide: @escaping () -> Void) {
        guard !isDismissing else { return }
        FeedbackGenerator.shared.tap()
        withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.3), completionCriteria: .removed) {
            if !reduceMotion {
                dragOffset = -max(bannerWidth + 32, abs(dragOffset) + 32)
            }
            isDismissing = true
        } completion: {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35), completionCriteria: .removed) {
                collapseProgress = 1
            } completion: {
                onHide()
            }
        }
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

// Keep the inset mounted while its height changes, so the list follows every animation frame.
private struct ResumeBannerCollapse: @preconcurrency AnimatableModifier {
    let height: CGFloat
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        // The banner fades out before collapsing; clipping here would cut off the horizontal swipe.
        content
            .frame(height: height > 0 ? max(0, height * (1 - progress)) : nil, alignment: .top)
    }
}
