import SwiftUI

public struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(AccessibleAccent.preferredForegroundColor(
                over: .accentColor,
                scheme: colorScheme
            ))
            .background(Color.accentColor, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}
