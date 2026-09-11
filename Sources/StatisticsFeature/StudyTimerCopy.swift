import Foundation

public enum StudyTimerCopy {
    public static func summary(
        _ snapshot: StudyTimerSnapshot,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let localizedBundle = Bundle.module.path(
            forResource: languageCode,
            ofType: "lproj"
        ).flatMap(Bundle.init(path:)) ?? .module
        let format = localizedBundle.localizedString(
            forKey: "study.timer.summary",
            value: "Today %1$@ · Session %2$@",
            table: nil
        )
        return String(
            format: format,
            locale: locale,
            StudyDurationFormatter.string(seconds: snapshot.todayElapsedSeconds),
            StudyDurationFormatter.string(seconds: snapshot.sessionElapsedSeconds)
        )
    }
}
