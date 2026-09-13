import Core
import DesignSystem
import SwiftUI

public struct StudyHistoryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: StudyHistoryViewModel
    @State private var selectedEntryID: UUID?
    private let resumableSnapshot: StudySessionSnapshot?
    private let onResume: () -> Void

    public init(
        model: StudyHistoryViewModel,
        resumableSnapshot: StudySessionSnapshot?,
        onResume: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        _selectedEntryID = State(initialValue: nil)
        self.resumableSnapshot = resumableSnapshot
        self.onResume = onResume
    }

    public var body: some View {
        content
            .transition(reduceMotion ? .identity : .opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.state)
            .navigationTitle(Text("history.title", bundle: .module))
            .navigationDestination(item: $selectedEntryID) { entryID in
                if let entry = model.entries.first(where: { $0.id == entryID }) {
                    StudyHistoryDetailView(entry: entry)
                }
            }
            .onAppear {
                guard model.state == .idle else { return }
                model.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView {
                Text("history.loading", bundle: .module)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            failureState
        case .loaded:
            loadedContent
        }
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label {
                Text("history.failure.title", bundle: .module)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } description: {
            Text("history.failure.message", bundle: .module)
        } actions: {
            HapticButton(action: model.load) {
                Text("history.retry", bundle: .module)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if model.entries.isEmpty, resumableSnapshot == nil {
            emptyState
        } else {
            List {
                if let resumableSnapshot {
                    Section {
                        ResumableStudyBanner(
                            snapshot: resumableSnapshot,
                            onResume: onResume
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("history.resume.section", bundle: .module)
                    }
                }

                if model.entries.isEmpty {
                    Section { emptyState }
                } else {
                    Section {
                        MetricTable(backgroundStyle: Color(uiColor: .secondarySystemGroupedBackground)) {
                            ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                                HapticButton {
                                    selectedEntryID = entry.id
                                } label: {
                                    StudyHistoryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("history.row.\(entry.id.uuidString)")

                                if index < model.entries.index(before: model.entries.endIndex) {
                                    MetricTableDivider(leadingInset: 56)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("history.sessions.section", bundle: .module)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("history.empty.title", bundle: .module)
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
        } description: {
            Text("history.empty.message", bundle: .module)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

private struct StudyHistoryRow: View {
    let entry: StudyHistoryEntry

    var body: some View {
        MetricTableRow(systemImage: modeSystemImage) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: HistoryPresentation.dateTime(entry.completedAt))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(verbatim: "\(entry.completedCardCount)/\(entry.plannedCardCount) · \(entry.recallRatePercentage)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } trailing: {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityLabel(
            "\(HistoryPresentation.dateTime(entry.completedAt)), "
                + "\(HistoryPresentation.mode(entry.mode)), "
                + "\(HistoryPresentation.progress(completed: entry.completedCardCount, total: entry.plannedCardCount)), "
                + HistoryPresentation.recall(entry.recallRatePercentage)
        )
    }

    private var modeSystemImage: String {
        switch entry.mode {
        case .flashcards:
            "rectangle.stack.fill"
        case .writing:
            "keyboard.fill"
        }
    }
}
