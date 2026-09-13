import Core
import DesignSystem
import SwiftUI

public struct StudyHistoryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let model: StudyHistoryViewModel
    private let resumableSnapshot: StudySessionSnapshot?
    private let onResume: () -> Void

    public init(
        model: StudyHistoryViewModel,
        resumableSnapshot: StudySessionSnapshot?,
        onResume: @escaping () -> Void
    ) {
        self.model = model
        self.resumableSnapshot = resumableSnapshot
        self.onResume = onResume
    }

    public var body: some View {
        content
            .transition(reduceMotion ? .identity : .opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.state)
            .navigationTitle(Text("history.title", bundle: .module))
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
                        ForEach(model.entries) { entry in
                            NavigationLink {
                                StudyHistoryDetailView(entry: entry)
                            } label: {
                                StudyHistoryRow(entry: entry)
                            }
                        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: HistoryPresentation.dateTime(entry.completedAt))
                .font(.headline)

            Text(verbatim: HistoryPresentation.mode(entry.mode))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metricText(HistoryPresentation.progress(
                        completed: entry.completedCardCount,
                        total: entry.plannedCardCount
                    ))
                    metricText(HistoryPresentation.recall(entry.recallRatePercentage))
                }

                VStack(alignment: .leading, spacing: 3) {
                    metricText(HistoryPresentation.progress(
                        completed: entry.completedCardCount,
                        total: entry.plannedCardCount
                    ))
                    metricText(HistoryPresentation.recall(entry.recallRatePercentage))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func metricText(_ value: String) -> some View {
        Text(verbatim: value)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
