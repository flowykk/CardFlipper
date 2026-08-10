import Core
import SwiftUI

public struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: CardEditorViewModel

    private let onSaved: @MainActor () async -> Void
    private let onCancel: () -> Void

    public init(
        model: CardEditorViewModel,
        onSaved: @escaping @MainActor () async -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    public var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                RussianMeaningsSection(
                    meanings: $model.russianMeanings,
                    showsValidationError: model.validationErrors.contains(.missingRussianMeaning),
                    onAdd: model.addRussianMeaning,
                    onRemove: model.removeRussianMeaning
                )

                EnglishVariantsSection(
                    variants: $model.englishVariants,
                    lookupState: model.lookupState,
                    showsValidationError: model.validationErrors.contains(.missingEnglishVariant),
                    onAdd: model.addEnglishVariant,
                    onRemove: model.removeEnglishVariant,
                    onTextChanged: model.scheduleLookup,
                    onLookup: { variantID in
                        Task { await model.lookup(variantID: variantID) }
                    },
                    onSpeak: model.speak,
                    onTogglePartOfSpeech: model.togglePartOfSpeech
                )

                TagPickerSection(
                    tags: model.availableTags,
                    selectedTagIDs: $model.selectedTagIDs,
                    newTagName: $model.newTagName,
                    loadFailed: model.tagLoadError,
                    creationFailed: model.tagCreationError,
                    onCreate: {
                        Task { await model.createTag() }
                    },
                    onRetryLoad: {
                        Task { await model.loadTags() }
                    }
                )

                if let saveError = model.saveError {
                    Section {
                        Label(
                            saveError == .duplicateCheck
                                ? "editor.duplicate.check.failed"
                                : "editor.save.failed",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("editor.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                }
            }
            .alert(
                "editor.duplicate.title",
                isPresented: $model.isDuplicateConfirmationPresented
            ) {
                Button("editor.duplicate.saveAnyway") {
                    Task { await confirmDuplicateAndSave() }
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("editor.duplicate.message")
            }
            .task {
                await model.loadTags()
            }
        }
    }

    private func save() async {
        if await model.save() == .saved {
            await onSaved()
            dismiss()
        }
    }

    private func confirmDuplicateAndSave() async {
        if await model.confirmDuplicateAndSave() == .saved {
            await onSaved()
            dismiss()
        }
    }

    private func cancel() {
        model.cancel()
        onCancel()
        dismiss()
    }
}
