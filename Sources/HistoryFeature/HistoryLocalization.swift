import Foundation

enum HistoryLocalization {
    static func string(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: nil, table: nil)
    }

    static func string(_ key: String, language: String) -> String {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: any CVarArg...) -> String {
        String(
            format: string(key),
            locale: .autoupdatingCurrent,
            arguments: arguments
        )
    }
}
