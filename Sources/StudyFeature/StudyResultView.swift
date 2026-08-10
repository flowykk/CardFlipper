import Core
import DesignSystem
import SwiftUI

struct StudyResultMetric: Equatable, Sendable {
    let localizationKey: String
    let count: Int
}

struct StudyResultPresentation: Equatable, Sendable {
    let reviewedCards: StudyResultMetric
    let extraAttempts: StudyResultMetric

    init(result: StudyResult) {
        reviewedCards = StudyResultMetric(
            localizationKey: "study.result.cards",
            count: result.uniqueCardCount
        )
        extraAttempts = StudyResultMetric(
            localizationKey: "study.result.extraAttempts",
            count: result.forgottenCount
        )
    }
}

public struct StudyResultView: View {
    private let presentation: StudyResultPresentation
    private let onRepeat: () -> Void
    private let onFinish: () -> Void

    public init(
        result: StudyResult,
        onRepeat: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        presentation = StudyResultPresentation(result: result)
        self.onRepeat = onRepeat
        self.onFinish = onFinish
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("study.result.title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    resultRow(
                        title: Text(verbatim: localizedCount(presentation.reviewedCards)),
                        systemImage: "rectangle.stack.fill"
                    )
                    resultRow(
                        title: Text(verbatim: localizedCount(presentation.extraAttempts)),
                        systemImage: "arrow.uturn.backward.circle.fill"
                    )
                }

                VStack(spacing: 12) {
                    Button(action: onRepeat) {
                        Label("study.result.repeat", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("study.repeat")

                    Button(action: onFinish) {
                        Label("study.result.library", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("study.finish")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("study.result")
        .scrollBounceBehavior(.basedOnSize)
        .navigationBarBackButtonHidden()
    }

    private func resultRow(title: Text, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            title
                .font(.title3)
            Spacer()
        }
    }

    private func localizedCount(_ metric: StudyResultMetric) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(metric.localizationKey)),
            metric.count
        )
    }
}
