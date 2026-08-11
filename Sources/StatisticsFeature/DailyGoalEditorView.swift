import SwiftUI

enum DailyGoalEditorCopy {
    static func title(locale: Locale) -> String {
        let localizedBundle = locale.identifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .lazy
            .compactMap { Bundle.module.path(forResource: String($0), ofType: "lproj") }
            .compactMap(Bundle.init(path:))
            .first ?? Bundle.module

        return localizedBundle.localizedString(
            forKey: "progress.goalTitle",
            value: "progress.goalTitle",
            table: nil
        )
    }
}

struct DailyGoalEditorView: View {
    @Environment(\.locale) private var locale
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
            .navigationTitle(Text(verbatim: DailyGoalEditorCopy.title(locale: locale)))
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
