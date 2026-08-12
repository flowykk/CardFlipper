import Observation

@MainActor
@Observable
final class DailyGoalEditorModel {
    let minuteOptions = Array(1...240)
    var selectedMinutes: Int

    @ObservationIgnored
    private let onSave: (Int) -> Void

    init(
        goalMinutes: Int,
        onSave: @escaping (Int) -> Void
    ) {
        selectedMinutes = goalMinutes
        self.onSave = onSave
    }

    func confirm() {
        onSave(selectedMinutes)
    }
}
