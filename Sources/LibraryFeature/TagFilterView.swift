import Core
import SwiftUI

public struct TagFilterView: View {
    private let tags: [Tag]
    @Binding private var selectedTagIDs: Set<UUID>
    private let onRequestDeletion: (Tag) -> Void

    public init(
        tags: [Tag],
        selectedTagIDs: Binding<Set<UUID>>,
        onRequestDeletion: @escaping (Tag) -> Void
    ) {
        self.tags = tags
        _selectedTagIDs = selectedTagIDs
        self.onRequestDeletion = onRequestDeletion
    }

    public var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(tags) { tag in
                        filterButton(for: tag)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            tagManagementMenu
        }
    }

    private func filterButton(for tag: Tag) -> some View {
        let isSelected = selectedTagIDs.contains(tag.id)

        return Button {
            if isSelected {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
                Text(verbatim: tag.name)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button(role: .destructive) {
                onRequestDeletion(tag)
            } label: {
                Label("common.delete", systemImage: "trash")
            }
        }
    }

    private var tagManagementMenu: some View {
        Menu {
            ForEach(tags) { tag in
                Button(role: .destructive) {
                    onRequestDeletion(tag)
                } label: {
                    Label {
                        Text(verbatim: tag.name)
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        } label: {
            Label("tag.manage", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(Text("tag.manage"))
    }
}
