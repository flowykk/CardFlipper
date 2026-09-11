import Core
import DesignSystem
import SwiftUI

public struct TagFilterView: View {
    private let tags: [Tag]
    @Binding private var selectedTagIDs: Set<UUID>
    private let onManageTags: () -> Void

    public init(
        tags: [Tag],
        selectedTagIDs: Binding<Set<UUID>>,
        onManageTags: @escaping () -> Void
    ) {
        self.tags = tags
        _selectedTagIDs = selectedTagIDs
        self.onManageTags = onManageTags
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
            .contentMargins(.leading, 20, for: .scrollContent)

            Button(action: onManageTags) {
                Label("tag.manage", systemImage: AppSymbol.tags)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("library.tags.manage")
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
            FeedbackGenerator.shared.selection()
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
    }
}
