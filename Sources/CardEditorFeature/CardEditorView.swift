import Core
import DesignSystem
import SwiftUI

public struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: CardEditorViewModel
    @State private var isDiscardConfirmationPresented = false

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
                    showsValidationError: model.displayedValidationErrors.contains(.missingRussianMeaning),
                    onAdd: model.addRussianMeaning,
                    onRemove: model.removeRussianMeaning
                )

                EnglishVariantsSection(
                    variants: $model.englishVariants,
                    expandedMetadataVariantIDs: $model.expandedMetadataVariantIDs,
                    lookupState: model.lookupState,
                    showsValidationError: model.displayedValidationErrors.contains(.missingEnglishVariant),
                    onAdd: model.addEnglishVariant,
                    onRemove: model.removeEnglishVariant,
                    onTextChanged: model.scheduleLookup,
                    onLookup: { variantID in
                        Task { await model.lookup(variantID: variantID) }
                    },
                    onSpeak: model.speak,
                    onIPAChanged: model.markIPAUserEdited,
                    onToggleMetadata: model.toggleMetadata,
                    onTogglePartOfSpeech: model.togglePartOfSpeech,
                    onAddUsageExample: model.addUsageExample,
                    onRemoveUsageExample: model.removeUsageExample,
                    onSpeakUsageExample: model.speakUsageExample,
                    onChooseUsageExamplePart: model.chooseUsageExamplePartOfSpeech,
                    onUseSuggestion: model.useDictionarySuggestion
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
            .scrollDismissesKeyboard(.immediately)
            .accessibilityIdentifier("editor.root")
            .navigationTitle("editor.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: cancel)
                        .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if model.isSaving {
                            ProgressView()
                        } else {
                            Text("common.save")
                        }
                    }
                    .disabled(model.isSaving)
                    .accessibilityIdentifier("editor.save")
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
            .alert(
                "editor.discard.title",
                isPresented: $isDiscardConfirmationPresented
            ) {
                Button("editor.discard.confirm", role: .destructive) {
                    discardAndDismiss()
                }
                Button("editor.discard.continue", role: .cancel) {}
            } message: {
                Text("editor.discard.message")
            }
            .task {
                await model.loadTags()
            }
        }
        .interactiveDismissDisabled(model.isDirty && !model.didSave)
        .onDisappear {
            model.cancelLookupOperations()
        }
    }

    private func save() async {
        if await model.save() == .saved {
            FeedbackGenerator.shared.successfulSave()
            await onSaved()
            dismiss()
        }
    }

    private func confirmDuplicateAndSave() async {
        if await model.confirmDuplicateAndSave() == .saved {
            FeedbackGenerator.shared.successfulSave()
            await onSaved()
            dismiss()
        }
    }

    private func cancel() {
        guard model.canDismissWithoutConfirmation else {
            isDiscardConfirmationPresented = true
            return
        }
        discardAndDismiss()
    }

    private func discardAndDismiss() {
        model.discardChanges()
        onCancel()
        dismiss()
    }
}
