import Testing
@testable import CardEditorFeature

@Test func repeatedEditorActionsIncludeTheirOneBasedRowPosition() {
    let translations = [
        "editor.russian.remove.position": "Remove Russian meaning %lld",
        "editor.english.remove.position": "Remove English variant %lld",
        "editor.english.speak.position": "Pronounce English variant %lld",
        "editor.example.remove.position": "Remove example %2$lld from English variant %1$lld",
        "editor.example.speak.position": "Pronounce example %2$lld from English variant %1$lld",
    ]
    let labels = EditorAccessibilityLabels { key in
        translations[key] ?? key
    }

    #expect(labels.removeRussianMeaning(position: 1) == "Remove Russian meaning 1")
    #expect(labels.removeRussianMeaning(position: 2) == "Remove Russian meaning 2")
    #expect(labels.removeEnglishVariant(position: 2) == "Remove English variant 2")
    #expect(labels.speakEnglishVariant(position: 2) == "Pronounce English variant 2")
    #expect(
        labels.removeUsageExample(variantPosition: 2, examplePosition: 3)
            == "Remove example 3 from English variant 2"
    )
    #expect(
        labels.speakUsageExample(variantPosition: 2, examplePosition: 3)
            == "Pronounce example 3 from English variant 2"
    )
}
