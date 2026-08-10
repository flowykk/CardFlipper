import Foundation

struct EditorAccessibilityLabels {
    typealias Localizer = (String) -> String

    private let localize: Localizer

    init(localize: @escaping Localizer = { key in
        String(localized: String.LocalizationValue(key))
    }) {
        self.localize = localize
    }

    func removeRussianMeaning(position: Int) -> String {
        label(for: "editor.russian.remove.position", position: position)
    }

    func removeEnglishVariant(position: Int) -> String {
        label(for: "editor.english.remove.position", position: position)
    }

    func speakEnglishVariant(position: Int) -> String {
        label(for: "editor.english.speak.position", position: position)
    }

    private func label(for key: String, position: Int) -> String {
        String.localizedStringWithFormat(localize(key), position)
    }
}
