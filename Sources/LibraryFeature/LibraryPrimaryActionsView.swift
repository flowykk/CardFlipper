import DesignSystem
import SwiftUI

struct LibraryStudyToolbarButton: View {
    let cardCount: Int
    let onStartStudy: () -> Void

    var body: some View {
        Button(action: onStartStudy) {
            Image(systemName: AppSymbol.study)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityIdentifier("library.study")
    }

    private var title: String {
        String.localizedStringWithFormat(
            String(localized: "library.studyToday", bundle: .main),
            cardCount
        )
    }
}
