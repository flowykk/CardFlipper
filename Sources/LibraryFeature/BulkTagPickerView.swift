import Core
import SwiftUI

struct BulkTagPickerView: View {
    let tags: [Tag]
    @Binding var selectedTagIDs: Set<UUID>
    let selectedCardCount: Int
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canConfirm: Bool {
        !selectedTagIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            List(tags) { tag in
                let isSelected = selectedTagIDs.contains(tag.id)

                Button {
                    withAnimation(selectionAnimation) {
                        toggle(tag.id)
                    }
                } label: {
                    HStack {
                        Text(verbatim: tag.name)
                        Spacer()
                        selectionIndicator(isSelected: isSelected)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("library.bulk.tag.\(tag.id.uuidString)")
            }
            .navigationTitle("library.bulk.tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onConfirm) {
                        Text(
                            String(
                                format: String(localized: "library.bulk.addTags", bundle: .main),
                                selectedCardCount
                            )
                        )
                    }
                    .foregroundStyle(canConfirm ? Color.accentColor : Color.secondary)
                    .opacity(canConfirm ? 1 : 0.55)
                    .disabled(!canConfirm)
                    .animation(selectionAnimation, value: canConfirm)
                    .accessibilityIdentifier("library.bulk.confirm")
                }
            }
        }
    }

    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .smooth(duration: 0.22)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .contentTransition(
                reduceMotion ? .opacity : .symbolEffect(.replace)
            )
            .accessibilityHidden(true)
    }

    private func toggle(_ id: UUID) {
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }
}
