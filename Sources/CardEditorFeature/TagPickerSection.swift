import Core
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
            ForEach(tags) { tag in
                Button {
                    toggle(tag.id)
                } label: {
                    HStack {
                        Text(verbatim: tag.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: selectedTagIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTagIDs.contains(tag.id) ? Color.accentColor : .secondary)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTagIDs.contains(tag.id) ? .isSelected : [])
            }

            HStack {
                TextField("editor.tag.new.placeholder", text: $newTagName)
                    .textInputAutocapitalization(.words)
                    .onSubmit(onCreate)

                Button(action: onCreate) {
                    Image(systemName: "plus.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("editor.tag.create")
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
    }
}
