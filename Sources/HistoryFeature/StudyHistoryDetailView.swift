import Core
import DesignSystem
import Foundation
import SwiftUI

public struct StudyHistoryDetailView: View {
    private let entry: StudyHistoryEntry

    public init(entry: StudyHistoryEntry) {
        self.entry = entry
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MetricTable(backgroundStyle: Color(uiColor: .secondarySystemGroupedBackground)) {
                    detailRow(
                        "history.completedAt.label",
                        systemImage: "checkmark.circle.fill",
                        value: HistoryPresentation.dateTime(entry.completedAt)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.startedAt.label",
                        systemImage: "play.circle.fill",
                        value: HistoryPresentation.dateTime(entry.startedAt)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.duration.label",
                        systemImage: "timer",
                        value: HistoryPresentation.duration(entry.elapsedSeconds)
                    )
                }

                MetricTable(backgroundStyle: Color(uiColor: .secondarySystemGroupedBackground)) {
                    detailRow(
                        "history.mode.label",
                        systemImage: entry.mode == .writing ? "pencil.line" : "rectangle.stack.fill",
                        value: HistoryPresentation.mode(entry.mode)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.direction.label",
                        systemImage: "arrow.left.arrow.right",
                        value: HistoryPresentation.direction(entry.direction)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.progress.label",
                        systemImage: "chart.bar.fill",
                        value: HistoryPresentation.progress(
                            completed: entry.completedCardCount,
                            total: entry.plannedCardCount
                        )
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.recall.label",
                        systemImage: "target",
                        value: HistoryPresentation.recall(entry.recallRatePercentage)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.encountered.label",
                        systemImage: "eye.fill",
                        value: String(entry.encounteredCardCount)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.repeated.label",
                        systemImage: "arrow.clockwise",
                        value: String(entry.repeatedCardCount)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.forgotten.label",
                        systemImage: "xmark.circle.fill",
                        value: String(entry.forgottenCount)
                    )
                    MetricTableDivider(leadingInset: 56)
                    detailRow(
                        "history.assessments.label",
                        systemImage: "checklist",
                        value: String(entry.totalAssessmentCount)
                    )
                }

                MetricTable(backgroundStyle: Color(uiColor: .secondarySystemGroupedBackground)) {
                    detailRow(
                        "history.tags.label",
                        systemImage: "tag.fill",
                        value: HistoryPresentation.tags(entry.selectedTagNames)
                    )
                }

                if !entry.difficultCardTitles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("history.difficultCards.label", bundle: .module)
                            .font(.headline)
                            .padding(.horizontal, 4)

                        MetricTable(backgroundStyle: Color(uiColor: .secondarySystemGroupedBackground)) {
                            ForEach(Array(entry.difficultCardTitles.enumerated()), id: \.element) { index, title in
                                MetricTableRow(systemImage: "exclamationmark.triangle.fill") {
                                    Text(verbatim: title)
                                        .font(.body)
                                } trailing: {
                                    EmptyView()
                                }
                                .accessibilityIdentifier("history.difficult.\(title)")

                                if index < entry.difficultCardTitles.index(before: entry.difficultCardTitles.endIndex) {
                                    MetricTableDivider(leadingInset: 56)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Text("history.detail.title", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func detailRow(
        _ labelKey: String,
        systemImage: String,
        value: String
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            MetricTableRow(systemImage: systemImage) {
                Text(LocalizedStringKey(labelKey), bundle: .module)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } trailing: {
                Text(verbatim: value)
                    .font(.body.weight(.regular))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }

            MetricTableRow(systemImage: systemImage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(labelKey), bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(verbatim: value)
                        .font(.body.weight(.regular))
                        .monospacedDigit()
                }
            } trailing: {
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(labelKey.replacingOccurrences(of: ".label", with: "")
            .replacingOccurrences(of: "history.", with: "history.detail."))
    }
}

enum HistoryPresentation {
    static func mode(_ mode: StudyMode) -> String {
        switch mode {
        case .flashcards:
            HistoryLocalization.string("history.mode.flashcards")
        case .writing:
            HistoryLocalization.string("history.mode.writing")
        }
    }

    static func direction(_ direction: StudyDirection) -> String {
        switch direction {
        case .russianToEnglish:
            HistoryLocalization.string("history.direction.russianToEnglish")
        case .englishToRussian:
            HistoryLocalization.string("history.direction.englishToRussian")
        }
    }

    static func progress(completed: Int, total: Int) -> String {
        HistoryLocalization.format("history.progress.format", completed, total)
    }

    static func recall(_ percentage: Int) -> String {
        HistoryLocalization.format("history.recall.format", percentage)
    }

    static func duration(_ seconds: Int) -> String {
        HistoryLocalization.format("history.duration.format", seconds)
    }

    static func tags(_ names: [String]) -> String {
        names.isEmpty
            ? HistoryLocalization.string("history.allCards")
            : names.joined(separator: ", ")
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
