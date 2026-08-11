import SwiftUI

struct ActivityCalendarView: View {
    @Bindable var model: ProgressDashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: model.moveToPreviousMonth) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(model.monthTitle).font(.headline)
                Spacer()
                Button(action: model.moveToNextMonth) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canMoveToNextMonth)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(model.days) { cell in
                    if let number = cell.dayNumber, let date = cell.date {
                        ZStack {
                            Circle()
                                .fill(cell.isAchieved ? Color.accentColor : .clear)
                            Circle()
                                .stroke(cell.isToday ? Color.primary : .clear, lineWidth: 1.5)
                            if cell.isAchieved {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            } else {
                                Text(number.formatted()).font(.caption)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue(cell.isAchieved ? Text("progress.completed", bundle: .module) : Text("progress.notCompleted", bundle: .module))
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
