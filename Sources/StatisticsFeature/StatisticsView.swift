import DesignSystem
import SwiftUI

public struct StatisticsView: View {
    private let statistics: StudyStatistics
    private let libraryCardCount: Int
    @State private var progressModel: ProgressDashboardViewModel
    private let onStartStudy: () -> Void

    public init(
        statistics: StudyStatistics,
        progress: any DailyProgressRepository,
        libraryCardCount: Int,
        calendar: Calendar = .autoupdatingCurrent,
        onStartStudy: @escaping () -> Void = {}
    ) {
        self.statistics = statistics
        self.libraryCardCount = libraryCardCount
        self.onStartStudy = onStartStudy
        _progressModel = State(initialValue: ProgressDashboardViewModel(
            progress: progress,
            calendar: calendar
        ))
    }

    public var body: some View {
        @Bindable var progressModel = progressModel
        ScrollView {
            if statistics.completedLessonCount == 0 {
                zeroState
                    .frame(maxWidth: .infinity, minHeight: 460)
                    .padding()
            } else {
                VStack(spacing: 16) {
                    todayCard
                    ActivityCalendarView(model: progressModel)
                    metricTable(
                        StatisticsMetric.makeOverviewMetrics(
                            libraryCardCount: libraryCardCount,
                            trend: progressModel.trend
                        )
                    )
                    ForEach(
                        StatisticsMetric.makeModeSections(statistics: statistics),
                        id: \.titleKey
                    ) { section in
                        metricSection(section)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(Text("statistics.title", bundle: .module))
        .scrollBounceBehavior(.basedOnSize)
        .onAppear(perform: progressModel.refresh)
        .sheet(isPresented: $progressModel.isGoalEditorPresented) {
            DailyGoalEditorView(model: progressModel)
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("progress.today", bundle: .module).font(.headline)
                Spacer()
                HapticButton {
                    progressModel.isGoalEditorPresented = true
                } label: {
                    Text("progress.editGoal", bundle: .module)
                }
            }
            Text("\(StudyDurationFormatter.string(seconds: progressModel.todayProgress.elapsedSeconds)) / \(StudyDurationFormatter.string(seconds: progressModel.todayProgress.goalSeconds))")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
            ProgressView(value: progressModel.progressFraction)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func metricSection(_ section: StatisticsMetricSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(section.titleKey), bundle: .module)
                .font(.headline)
                .padding(.horizontal, 4)
            metricTable(section.metrics)
        }
    }

    private func metricTable(_ metrics: [StatisticsMetric]) -> some View {
        MetricTable {
            ForEach(metrics.indices, id: \.self) { index in
                metricRow(metrics[index])
                if index < metrics.index(before: metrics.endIndex) {
                    MetricTableDivider(leadingInset: 56)
                }
            }
        }
    }

    private func metricRow(_ metric: StatisticsMetric) -> some View {
        MetricTableRow(systemImage: metric.systemImage) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(metric.titleKey), bundle: .module)
                    .font(.body)
                if let subtitleKey = metric.subtitleKey {
                    Text(LocalizedStringKey(subtitleKey), bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: metric.value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                if let detail = metric.detail {
                    (
                        Text(verbatim: detail)
                        + Text(verbatim: " ")
                        + Text("statistics.vsPrevious", bundle: .module)
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(detail.hasPrefix("+") ? Color.green : .secondary)
                }
            }
        }
    }

    private var zeroState: some View {
        ContentUnavailableView {
            Label {
                Text("statistics.zero.title", bundle: .module)
            } icon: {
                Image(systemName: AppSymbol.statistics)
            }
        } description: {
            Text("statistics.zero.message", bundle: .module)
        } actions: {
            HapticButton(action: onStartStudy) {
                Label {
                    Text("statistics.zero.action", bundle: .module)
                } icon: {
                    Image(systemName: AppSymbol.study)
                }
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("statistics.startStudy")
        }
        .accessibilityIdentifier("statistics.zeroState")
    }
}
