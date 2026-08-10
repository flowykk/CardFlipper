import SwiftUI

public struct RussianMeaningsSection: View {
    @Binding private var meanings: [RussianMeaningInput]
    private let showsValidationError: Bool
    private let onAdd: () -> Void
    private let onRemove: (UUID) -> Void
    private let accessibilityLabels = EditorAccessibilityLabels()

    public init(
        meanings: Binding<[RussianMeaningInput]>,
        showsValidationError: Bool,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (UUID) -> Void
    ) {
        _meanings = meanings
        self.showsValidationError = showsValidationError
        self.onAdd = onAdd
        self.onRemove = onRemove
    }

    public var body: some View {
        Section {
            ForEach($meanings) { $meaning in
                HStack(alignment: .firstTextBaseline) {
                    TextField("editor.russian.placeholder", text: $meaning.text)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("editor.russian.value")

                    Button(role: .destructive) {
                        onRemove(meaning.id)
                    } label: {
                        Image(systemName: "minus.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: accessibilityLabels.removeRussianMeaning(
                        position: position(of: meaning.id)
                    )))
                }
            }

            Button(action: onAdd) {
                Label("editor.russian.add", systemImage: "plus.circle")
            }

            if showsValidationError {
                Label("editor.russian.required", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("editor.russian.required")
            }
        } header: {
            Text("editor.russian.title")
        }
    }

    private func position(of id: UUID) -> Int {
        meanings.firstIndex { $0.id == id }.map { $0 + 1 } ?? 1
    }
}
