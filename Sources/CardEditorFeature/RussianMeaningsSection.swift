import SwiftUI

public struct RussianMeaningsSection: View {
    @Binding private var meanings: [RussianMeaningInput]
    @FocusState private var focusedMeaningID: UUID?
    @State private var blurredMeaningIDs: Set<UUID> = []
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
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        meaningField(meaning: $meaning)
                            .frame(minWidth: 220)
                        removeButton(for: meaning.id)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        meaningField(meaning: $meaning)
                        removeButton(for: meaning.id)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            Button(action: onAdd) {
                Label("editor.russian.add", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("editor.russian.add")

            if shouldShowValidationError {
                Label("editor.russian.required", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("editor.russian.required")
            }
        } header: {
            Text("editor.russian.title")
        }
        .onChange(of: focusedMeaningID) { oldValue, _ in
            if let oldValue {
                blurredMeaningIDs.insert(oldValue)
            }
        }
    }

    private func meaningField(meaning: Binding<RussianMeaningInput>) -> some View {
        let id = meaning.wrappedValue.id
        return TextField("editor.russian.placeholder", text: meaning.text)
            .textInputAutocapitalization(.sentences)
            .focused($focusedMeaningID, equals: id)
            .accessibilityLabel("editor.russian.value")
            .accessibilityIdentifier("editor.russian.\(position(of: id) - 1)")
    }

    private func removeButton(for id: UUID) -> some View {
        Button(role: .destructive) {
            onRemove(id)
        } label: {
            Image(systemName: "minus.circle")
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: accessibilityLabels.removeRussianMeaning(
            position: position(of: id)
        )))
    }

    private var shouldShowValidationError: Bool {
        showsValidationError || (
            !blurredMeaningIDs.isEmpty
                && meanings.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
    }

    private func position(of id: UUID) -> Int {
        meanings.firstIndex { $0.id == id }.map { $0 + 1 } ?? 1
    }
}
