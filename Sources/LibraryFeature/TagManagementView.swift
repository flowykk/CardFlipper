import Core
import DesignSystem
import SwiftUI

public struct TagManagementView: View {
    @Bindable private var model: LibraryViewModel
    @State private var newTagName = ""
    @State private var selectedTag: Tag?

    private let onDataChanged: @MainActor () async -> Void

    public init(
        model: LibraryViewModel,
        onDataChanged: @escaping @MainActor () async -> Void = {}
    ) {
        self.model = model
        self.onDataChanged = onDataChanged
    }

    public var body: some View {
        List {
            Section("tag.create.title") {
                ViewThatFits(in: .horizontal) {
                    HStack { createFields }
                    VStack(alignment: .leading, spacing: 8) { createFields }
                }
            }

            Section("tag.manage") {
                if model.tags.isEmpty {
                    ContentUnavailableView(
                        "tag.empty.title",
                        systemImage: AppSymbol.tags,
                        description: Text("tag.empty.message")
                    )
                } else {
                    ForEach(model.tags) { tag in
                        HapticButton {
                            selectedTag = tag
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: AppSymbol.tags)
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: tag.name)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(verbatim: affectedText(for: tag.id))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.forward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("tag.manage.\(tag.id)")
                    }
                }
            }
        }
        .navigationTitle("tag.manage")
        .sheet(item: $selectedTag) { tag in
            NavigationStack {
                TagManagementDetailView(
                    tag: tag,
                    allTags: model.tags,
                    affectedCardCount: model.affectedCardCount(for: tag.id),
                    onRename: { name in
                        let changed = await model.renameTag(id: tag.id, name: name)
                        if changed { await onDataChanged() }
                        return changed
                    },
                    onMerge: { destinationID in
                        let changed = await model.mergeTag(id: tag.id, into: destinationID)
                        if changed { await onDataChanged() }
                        return changed
                    },
                    onDelete: {
                        model.pendingTagDeletion = tag
                        let changed = await model.deletePendingTag()
                        if changed { await onDataChanged() }
                        return changed
                    }
                )
            }
        }
        .alert("data.save.failed", isPresented: mutationFailureBinding) {
            HapticButton("common.close", role: .cancel) { model.dismissTagMutationFailure() }
        }
    }

    @ViewBuilder
    private var createFields: some View {
        TextField("tag.create.placeholder", text: $newTagName)
            .textInputAutocapitalization(.words)
            .onSubmit(createTag)
            .accessibilityIdentifier("tag.create.name")
        HapticButton("tag.create.action", action: createTag)
            .buttonStyle(.borderedProminent)
            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("tag.create")
    }

    private var mutationFailureBinding: Binding<Bool> {
        Binding(
            get: { model.tagMutationFailed },
            set: { if !$0 { model.dismissTagMutationFailure() } }
        )
    }

    private func createTag() {
        let name = newTagName
        Task {
            if await model.createTag(name: name) {
                newTagName = ""
                await onDataChanged()
            }
        }
    }

    private func affectedText(for tagID: UUID) -> String {
        String.localizedStringWithFormat(
            String(localized: "tag.affected", bundle: .main),
            model.affectedCardCount(for: tagID)
        )
    }
}

private struct TagManagementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let tag: Tag
    let allTags: [Tag]
    let affectedCardCount: Int
    let onRename: (String) async -> Bool
    let onMerge: (UUID) async -> Bool
    let onDelete: () async -> Bool

    @State private var name: String
    @State private var destinationID: UUID?
    @State private var isShowingMergeConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isWorking = false

    init(
        tag: Tag,
        allTags: [Tag],
        affectedCardCount: Int,
        onRename: @escaping (String) async -> Bool,
        onMerge: @escaping (UUID) async -> Bool,
        onDelete: @escaping () async -> Bool
    ) {
        self.tag = tag
        self.allTags = allTags
        self.affectedCardCount = affectedCardCount
        self.onRename = onRename
        self.onMerge = onMerge
        self.onDelete = onDelete
        _name = State(initialValue: tag.name)
    }

    var body: some View {
        Form {
            Section("tag.rename.title") {
                TextField("tag.create.placeholder", text: $name)
                    .submitLabel(.done)
                    .onSubmit {
                        if canRename { performRename() }
                    }
                    .accessibilityIdentifier("tag.rename.name")
            }

            if !mergeDestinations.isEmpty {
                Section {
                    Picker(
                        "tag.merge.destination",
                        selection: $destinationID.withSelectionFeedback()
                    ) {
                        Text("tag.merge.choose").tag(nil as UUID?)
                        ForEach(mergeDestinations) { destination in
                            Text(verbatim: destination.name).tag(destination.id as UUID?)
                        }
                    }
                    HapticButton("tag.merge.action") { isShowingMergeConfirmation = true }
                        .disabled(isWorking || destinationID == nil)
                } header: {
                    Text("tag.merge.title")
                } footer: {
                    Text(verbatim: affectedText)
                }
            }

            Section {
                HapticButton("tag.delete.action", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
                .disabled(isWorking)
            } footer: {
                Text(verbatim: affectedText)
            }
        }
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                HapticButton("common.close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                HapticButton("common.save") { performRename() }
                    .disabled(!canRename)
                    .accessibilityIdentifier("tag.rename.save")
            }
        }
        .confirmationDialog(
            "tag.merge.confirm.title",
            isPresented: $isShowingMergeConfirmation,
            titleVisibility: .visible
        ) {
            HapticButton("tag.merge.action") { performMerge() }
            HapticButton("common.cancel", role: .cancel) {}
        } message: {
            Text(verbatim: affectedText)
        }
        .confirmationDialog(
            "tag.delete.title",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            HapticButton("tag.delete.action", role: .destructive) { performDelete() }
            HapticButton("common.cancel", role: .cancel) {}
        } message: {
            Text(verbatim: affectedText)
        }
    }

    private var mergeDestinations: [Tag] { allTags.filter { $0.id != tag.id } }
    private var normalizedName: String { TextNormalizer.searchKey(name) }
    private var normalizedOriginalName: String { TextNormalizer.searchKey(tag.name) }
    private var canRename: Bool {
        !isWorking && !normalizedName.isEmpty && normalizedName != normalizedOriginalName
    }
    private var affectedText: String {
        String.localizedStringWithFormat(
            String(localized: "tag.affected", bundle: .main),
            affectedCardCount
        )
    }

    private func performRename() {
        isWorking = true
        Task {
            if await onRename(name) { dismiss() }
            isWorking = false
        }
    }

    private func performMerge() {
        guard let destinationID else { return }
        isWorking = true
        Task {
            if await onMerge(destinationID) { dismiss() }
            isWorking = false
        }
    }

    private func performDelete() {
        isWorking = true
        Task {
            if await onDelete() { dismiss() }
            isWorking = false
        }
    }
}
