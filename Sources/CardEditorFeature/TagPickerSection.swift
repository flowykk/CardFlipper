import Core
import DesignSystem
import SwiftUI

public struct TagPickerSection: View {
    private let tags: [Tag]
    @Binding private var selectedTagIDs: Set<UUID>
    @Binding private var newTagName: String
    private let loadFailed: Bool
    private let creationFailed: Bool
    private let onCreate: () -> Void
    private let onRetryLoad: () -> Void

    public init(
        tags: [Tag],
        selectedTagIDs: Binding<Set<UUID>>,
        newTagName: Binding<String>,
        loadFailed: Bool,
        creationFailed: Bool,
        onCreate: @escaping () -> Void,
        onRetryLoad: @escaping () -> Void
    ) {
        self.tags = tags
        _selectedTagIDs = selectedTagIDs
        _newTagName = newTagName
        self.loadFailed = loadFailed
        self.creationFailed = creationFailed
        self.onCreate = onCreate
        self.onRetryLoad = onRetryLoad
    }

    public var body: some View {
        Section {
            if !tags.isEmpty {
                TagChipLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(tags) { tag in
                        tagButton(tag)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                TextField("editor.tag.new.placeholder", text: $newTagName)
                    .textInputAutocapitalization(.words)
                    .onSubmit(onCreate)
                    .accessibilityIdentifier("editor.tag.new")

                Button(action: onCreate) {
                    Image(systemName: "plus.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("editor.tag.create")
                .accessibilityIdentifier("editor.tag.create")
            }

            if creationFailed {
                Label("editor.tag.create.failed", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if loadFailed {
                Button(action: onRetryLoad) {
                    Label("editor.tag.load.retry", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("editor.tags.title")
        }
    }

    private func toggle(_ id: UUID) {
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
        FeedbackGenerator.shared.selection()
    }

    private func tagButton(_ tag: Tag) -> some View {
        let isSelected = selectedTagIDs.contains(tag.id)

        return Button {
            toggle(tag.id)
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(verbatim: tag.name)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.1))
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.tag.chip.\(tag.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
