import SwiftUI

public struct StatisticsView: View {
    private let statistics: StudyStatistics

    public init(statistics: StudyStatistics) {
        self.statistics = statistics
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 145), spacing: 12)],
                spacing: 12
            ) {
                metricCard(
                    title: "statistics.lessons",
                    value: statistics.completedLessonCount.formatted(),
                    systemImage: "graduationcap.fill"
                )
                metricCard(
                    title: "statistics.cards",
                    value: statistics.studiedCardCount.formatted(),
                    systemImage: "rectangle.stack.fill"
                )
                metricCard(
                    title: "statistics.forgotten",
                    value: statistics.forgottenCount.formatted(),
                    systemImage: "arrow.uturn.backward.circle.fill"
                )
                metricCard(
                    title: "statistics.average",
                    value: statistics.averageCardsPerLesson.formatted(
                        .number.precision(.fractionLength(1))
                    ),
                    systemImage: "chart.bar.fill"
                )
                metricCard(
                    title: "statistics.withoutForgetting",
                    value: "\(statistics.lessonsWithoutForgettingPercentage)%",
                    systemImage: "checkmark.seal.fill"
                )
            }
            .padding()
        }
        .navigationTitle(Text("statistics.title", bundle: .module))
        .scrollBounceBehavior(.basedOnSize)
    }

    private func metricCard(
        title: LocalizedStringKey,
        value: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(verbatim: value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText())

            Text(title, bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
