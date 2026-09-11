import DesignSystem
import SwiftUI

struct LibraryPrimaryActionsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let cardCount: Int
    let isStudyEnabled: Bool
    let onStartStudy: () -> Void
    let onAddCard: () -> Void

    init(
        cardCount: Int,
        isStudyEnabled: Bool = true,
        onStartStudy: @escaping () -> Void,
        onAddCard: @escaping () -> Void
    ) {
        self.cardCount = cardCount
        self.isStudyEnabled = isStudyEnabled
        self.onStartStudy = onStartStudy
        self.onAddCard = onAddCard
    }

    var body: some View {
        Group {
            if AdaptiveControlLayout.usesVerticalControls(
                dynamicTypeSize: dynamicTypeSize,
                horizontalSizeClass: horizontalSizeClass
            ) {
                VStack(spacing: 10) {
                    studyButton
                    addButton
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        studyButton
                        addButton
                    }
                    VStack(spacing: 10) {
                        studyButton
                        addButton
                    }
                }
            }
        }
        .controlSize(.large)
    }

    private var studyButton: some View {
        Button(action: onStartStudy) {
            Label {
                Text(verbatim: String.localizedStringWithFormat(
                    String(localized: "library.studyToday", bundle: .main),
                    cardCount
                ))
            } icon: {
                Image(systemName: AppSymbol.study)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isStudyEnabled)
        .accessibilityHint(isStudyEnabled ? "" : String(localized: "library.studyUnavailableReason", bundle: .main))
        .accessibilityIdentifier("library.study")
    }

    private var addButton: some View {
        Button(action: onAddCard) {
            Label("library.add", systemImage: "plus")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("library.add")
    }
}
