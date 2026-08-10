import Testing
@testable import CardEditorFeature

@Test func repeatedEditorActionsIncludeTheirOneBasedRowPosition() {
    let translations = [
        "editor.russian.remove.position": "Remove Russian meaning %lld",
        "editor.english.remove.position": "Remove English variant %lld",
        "editor.english.speak.position": "Pronounce English variant %lld",
    ]
    let labels = EditorAccessibilityLabels { key in
        translations[key] ?? key
    }

    #expect(labels.removeRussianMeaning(position: 1) == "Remove Russian meaning 1")
    #expect(labels.removeRussianMeaning(position: 2) == "Remove Russian meaning 2")
    #expect(labels.removeEnglishVariant(position: 2) == "Remove English variant 2")
    #expect(labels.speakEnglishVariant(position: 2) == "Pronounce English variant 2")
}
