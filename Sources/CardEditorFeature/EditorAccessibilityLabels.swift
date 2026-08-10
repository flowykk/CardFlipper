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

    func removeUsageExample(variantPosition: Int, examplePosition: Int) -> String {
        label(
            for: "editor.example.remove.position",
            variantPosition: variantPosition,
            examplePosition: examplePosition
        )
    }

    func speakUsageExample(variantPosition: Int, examplePosition: Int) -> String {
        label(
            for: "editor.example.speak.position",
            variantPosition: variantPosition,
            examplePosition: examplePosition
        )
    }

    private func label(for key: String, position: Int) -> String {
        String.localizedStringWithFormat(localize(key), position)
    }

    private func label(
        for key: String,
        variantPosition: Int,
        examplePosition: Int
    ) -> String {
        String.localizedStringWithFormat(
            localize(key),
            variantPosition,
            examplePosition
        )
    }
}
