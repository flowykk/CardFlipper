import SwiftUI

struct ActivityCalendarView: View {
    @Bindable var model: ProgressDashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: model.moveToPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("progress.previousMonth", bundle: .module))
                Spacer()
                Text(model.monthTitle).font(.headline)
                Spacer()
                Button(action: model.moveToNextMonth) {
                    Image(systemName: "chevron.right")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!model.canMoveToNextMonth)
                .accessibilityLabel(Text("progress.nextMonth", bundle: .module))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(model.days) { cell in
                    if let number = cell.dayNumber, let date = cell.date {
                        dayCell(number: number, cell: cell)
                        .frame(width: 32, height: 32)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(accessibilityValue(for: cell.state))
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
            legend
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func dayCell(number: Int, cell: ActivityCalendarDay) -> some View {
        ZStack {
            Circle()
                .fill(fillColor(for: cell.state))
            Circle()
                .stroke(strokeColor(for: cell), lineWidth: cell.isToday ? 2 : 1)
            if cell.state == .goalAchieved {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            } else {
                Text(number.formatted())
                    .font(.caption)
                    .foregroundStyle(cell.state == .future ? .tertiary : .primary)
            }
        }
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 8) { legendItems }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.caption)
    }

    @ViewBuilder
    private var legendItems: some View {
        legendItem(state: .noActivity, key: "progress.legend.noActivity")
        legendItem(state: .activeBelowGoal, key: "progress.legend.active")
        legendItem(state: .goalAchieved, key: "progress.legend.achieved")
    }

    private func legendItem(state: ActivityCalendarState, key: LocalizedStringKey) -> some View {
        Label {
            Text(key, bundle: .module)
        } icon: {
            ZStack {
                Circle()
                    .fill(fillColor(for: state))
                Circle()
                    .stroke(state == .noActivity ? Color.secondary : .clear, lineWidth: 1)
                if state == .goalAchieved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 12, height: 12)
        }
    }

    private func fillColor(for state: ActivityCalendarState) -> Color {
        switch state {
        case .future, .noActivity: .clear
        case .activeBelowGoal: .orange.opacity(0.3)
        case .goalAchieved: .accentColor
        }
    }

    private func strokeColor(for cell: ActivityCalendarDay) -> Color {
        if cell.isToday { return .primary }
        if cell.state == .noActivity { return .secondary.opacity(0.45) }
        return .clear
    }

    private func accessibilityValue(for state: ActivityCalendarState) -> Text {
        switch state {
        case .future: Text("progress.future", bundle: .module)
        case .noActivity: Text("progress.noActivity", bundle: .module)
        case .activeBelowGoal: Text("progress.activeBelowGoal", bundle: .module)
        case .goalAchieved: Text("progress.completed", bundle: .module)
        }
    }
}
