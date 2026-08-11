import SwiftUI

struct DailyGoalEditorView: View {
    @Bindable var model: ProgressDashboardViewModel

    var body: some View {
        NavigationStack {
            Form {
                Stepper(value: Binding(
                    get: { model.goalMinutes },
                    set: { model.setGoal(minutes: $0) }
                ), in: 1...240) {
                    HStack {
                        Text("progress.dailyGoal", bundle: .module)
                        Spacer()
                        Text("\(model.goalMinutes) min")
                    }
                }
            }
            .navigationTitle("progress.goalTitle")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        model.isGoalEditorPresented = false
                    } label: {
                        Text("progress.done", bundle: .module)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
