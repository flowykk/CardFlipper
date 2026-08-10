import SwiftUI

public struct FlashcardSurface<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .background(
                .background.secondary,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: .primary.opacity(0.08), radius: 16, y: 8)
            .contentShape(Rectangle())
    }
}
