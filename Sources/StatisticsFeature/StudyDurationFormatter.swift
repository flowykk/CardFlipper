import Foundation

public enum StudyDurationFormatter {
    public static func string(seconds: Int) -> String {
        let value = max(0, seconds)
        let hours = value / 3_600
        let minutes = (value % 3_600) / 60
        let seconds = value % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
