import Core
import DesignSystem
import Foundation
import SwiftUI

struct StudyResultMetric: Equatable, Sendable {
    let localizationKey: String
    let count: Int
}

struct StudyResultPresentation: Equatable, Sendable {
    let reviewedCards: StudyResultMetric
    let repeatedCards: StudyResultMetric
    let recallRatePercentage: Int
    let durationText: String
    let difficultCardTitles: [String]
    let dailyGoalPercentage: Int?

    init(
        result: StudyResult,
        difficultCards: [VocabularyCard] = [],
        dailyGoalProgress: StudyDailyGoalProgress? = nil
    ) {
        reviewedCards = StudyResultMetric(
            localizationKey: "study.result.cards",
            count: result.reviewedCardCount
        )
        repeatedCards = StudyResultMetric(
            localizationKey: "study.result.cardsRepeated",
            count: result.repeatedCardCount
        )
        recallRatePercentage = result.recallRatePercentage
        durationText = Self.durationText(seconds: result.elapsedSeconds)
        difficultCardTitles = difficultCards.map { card in
            let values = card.englishVariants.map(\.text)
            return values.isEmpty ? card.russianMeanings.map(\.text).joined(separator: " • ") : values.joined(separator: " • ")
        }
        dailyGoalPercentage = dailyGoalProgress.map {
            Int(($0.fractionCompleted * 100).rounded())
        }
    }

    private static func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

public struct StudyResultView: View {
    private let presentation: StudyResultPresentation
    private let onRepeatDifficult: (() -> Void)?
    private let onFinish: () -> Void

    public init(
        result: StudyResult,
        difficultCards: [VocabularyCard] = [],
        dailyGoalProgress: StudyDailyGoalProgress? = nil,
        onRepeatDifficult: (() -> Void)? = nil,
        onFinish: @escaping () -> Void
    ) {
        presentation = StudyResultPresentation(
            result: result,
            difficultCards: difficultCards,
            dailyGoalProgress: dailyGoalProgress
        )
        self.onRepeatDifficult = onRepeatDifficult
        self.onFinish = onFinish
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("study.result.title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    resultRow(
                        title: Text(verbatim: localizedCount(presentation.reviewedCards)),
                        systemImage: "rectangle.stack.fill"
                    )
                    resultRow(
                        title: Text(verbatim: localizedCount(presentation.repeatedCards)),
                        systemImage: "arrow.uturn.backward.circle.fill"
                    )
                    resultRow(
                        title: Text(verbatim: localizedPercentage(
                            key: "study.result.recallRate",
                            value: presentation.recallRatePercentage
                        )),
                        systemImage: "target"
                    )
                    resultRow(
                        title: Text(verbatim: localizedValue(
                            key: "study.result.duration",
                            value: presentation.durationText
                        )),
                        systemImage: "timer"
                    )
                    if let dailyGoalPercentage = presentation.dailyGoalPercentage {
                        resultRow(
                            title: Text(verbatim: localizedPercentage(
                                key: "study.result.dailyGoal",
                                value: dailyGoalPercentage
                            )),
                            systemImage: "chart.bar.fill"
                        )
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("study.result.summary")

                if !presentation.difficultCardTitles.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("study.result.difficult.title")
                            .font(.headline)
                        ForEach(Array(presentation.difficultCardTitles.enumerated()), id: \.offset) { _, title in
                            Label {
                                Text(verbatim: title)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("study.result.difficult")
                }

                VStack(spacing: 12) {
                    if let onRepeatDifficult {
                        Button(action: onRepeatDifficult) {
                            Label("study.result.repeatDifficult", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("study.repeat")
                    }

                    Button(action: onFinish) {
                        Label("common.done", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
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
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
        }
    }

    private func localizedCount(_ metric: StudyResultMetric) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(metric.localizationKey)),
            metric.count
        )
    }

    private func localizedPercentage(key: String, value: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            value
        )
    }

    private func localizedValue(key: String, value: String) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            value
        )
    }
}
