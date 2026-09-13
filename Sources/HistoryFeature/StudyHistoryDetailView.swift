import Core
import Foundation
import SwiftUI

public struct StudyHistoryDetailView: View {
    private let entry: StudyHistoryEntry

    public init(entry: StudyHistoryEntry) {
        self.entry = entry
    }

    public var body: some View {
        List {
            Section {
                detailRow("history.completedAt.label", HistoryPresentation.dateTime(entry.completedAt))
                detailRow("history.startedAt.label", HistoryPresentation.dateTime(entry.startedAt))
                detailRow("history.duration.label", HistoryPresentation.duration(entry.elapsedSeconds))
            }

            Section {
                detailRow("history.mode.label", HistoryPresentation.mode(entry.mode))
                detailRow("history.direction.label", HistoryPresentation.direction(entry.direction))
                detailRow(
                    "history.progress.label",
                    HistoryPresentation.progress(
                        completed: entry.completedCardCount,
                        total: entry.plannedCardCount
                    )
                )
                detailRow("history.recall.label", HistoryPresentation.recall(entry.recallRatePercentage))
                detailRow("history.encountered.label", String(entry.encounteredCardCount))
                detailRow("history.repeated.label", String(entry.repeatedCardCount))
                detailRow("history.forgotten.label", String(entry.forgottenCount))
                detailRow("history.assessments.label", String(entry.totalAssessmentCount))
            }

            Section {
                detailRow("history.tags.label", HistoryPresentation.tags(entry.selectedTagNames))
            }

            if !entry.difficultCardTitles.isEmpty {
                Section {
                    ForEach(entry.difficultCardTitles, id: \.self) { title in
                        Text(verbatim: title)
                            .frame(minHeight: 44, alignment: .leading)
                            .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("history.difficultCards.label", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("history.detail.title", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ labelKey: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(LocalizedStringKey(labelKey), bundle: .module)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(verbatim: value)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(labelKey), bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: value)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
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
