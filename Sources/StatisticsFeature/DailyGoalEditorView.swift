import DesignSystem
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
    @State private var editorModel: DailyGoalEditorModel

    init(model: ProgressDashboardViewModel) {
        self.model = model
        _editorModel = State(initialValue: DailyGoalEditorModel(
            goalMinutes: model.goalMinutes,
            onSave: model.setGoal(minutes:)
        ))
    }

    var body: some View {
        @Bindable var editorModel = editorModel

        NavigationStack {
            HStack(spacing: 0) {
                Picker(
                    selection: $editorModel.selectedMinutes.withSelectionFeedback(),
                    label: Text("progress.dailyGoal", bundle: .module)
                ) {
                    ForEach(editorModel.minuteOptions, id: \.self) { minutes in
                        Text(minutes.formatted()).tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .accessibilityLabel(Text("progress.dailyGoal", bundle: .module))
                .accessibilityValue(
                    Text("\(editorModel.selectedMinutes) ")
                    + Text("progress.minutesUnit", bundle: .module)
                )

                Text("progress.minutesUnit", bundle: .module)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
            .navigationTitle(Text(verbatim: DailyGoalEditorCopy.title(locale: locale)))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    HapticButton {
                        editorModel.confirm()
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
