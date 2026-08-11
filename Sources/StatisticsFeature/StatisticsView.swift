import SwiftUI

public struct StatisticsView: View {
    private let statistics: StudyStatistics
    private let libraryCardCount: Int
    @State private var progressModel: ProgressDashboardViewModel

    public init(
        statistics: StudyStatistics,
        progress: any DailyProgressRepository,
        libraryCardCount: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.statistics = statistics
        self.libraryCardCount = libraryCardCount
        _progressModel = State(initialValue: ProgressDashboardViewModel(
            progress: progress,
            calendar: calendar
        ))
    }

    public var body: some View {
        @Bindable var progressModel = progressModel
        ScrollView {
            VStack(spacing: 16) {
                todayCard
                ActivityCalendarView(model: progressModel)
                metricGrid
            }
            .padding()
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
                Button {
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

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            ForEach(
                StatisticsMetric.makeMetrics(
                    statistics: statistics,
                    libraryCardCount: libraryCardCount
                ),
                id: \.titleKey
            ) { metric in
                metricCard(
                    title: LocalizedStringKey(metric.titleKey),
                    value: metric.value,
                    systemImage: metric.systemImage
                )
            }
        }
    }

    private func metricCard(title: LocalizedStringKey, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage).font(.title2).foregroundStyle(Color.accentColor).accessibilityHidden(true)
            Text(verbatim: value).font(.system(.title, design: .rounded, weight: .bold))
            Text(title, bundle: .module).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
