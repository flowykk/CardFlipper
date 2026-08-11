import SwiftUI

public struct StatisticsView: View {
    private let statistics: StudyStatistics
    @State private var progressModel: ProgressDashboardViewModel

    public init(
        statistics: StudyStatistics,
        progress: any DailyProgressRepository,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.statistics = statistics
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
                metrics
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

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            metricCard(title: "statistics.lessons", value: statistics.completedLessonCount.formatted(), systemImage: "graduationcap.fill")
            metricCard(title: "statistics.cards", value: statistics.studiedCardCount.formatted(), systemImage: "rectangle.stack.fill")
            metricCard(title: "statistics.forgotten", value: statistics.forgottenCount.formatted(), systemImage: "arrow.uturn.backward.circle.fill")
            metricCard(title: "statistics.average", value: statistics.averageCardsPerLesson.formatted(.number.precision(.fractionLength(1))), systemImage: "chart.bar.fill")
            metricCard(title: "statistics.withoutForgetting", value: "\(statistics.lessonsWithoutForgettingPercentage)%", systemImage: "checkmark.seal.fill")
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
