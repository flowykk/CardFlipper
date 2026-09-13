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

public struct MetricTable<Content: View>: View {
    private let backgroundStyle: AnyShapeStyle
    private let content: Content

    public init<Background: ShapeStyle>(
        backgroundStyle: Background,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundStyle = AnyShapeStyle(backgroundStyle)
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 18))
    }
}

public struct MetricTableRow<Leading: View, Trailing: View>: View {
    private let systemImage: String?
    private let leading: Leading
    private let trailing: Trailing

    public init(
        systemImage: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.systemImage = systemImage
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }

            leading
            Spacer(minLength: 12)
            trailing
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

public struct MetricTableDivider: View {
    private let leadingInset: CGFloat

    public init(leadingInset: CGFloat = 0) {
        self.leadingInset = leadingInset
    }

    public var body: some View {
        Divider().padding(.leading, leadingInset)
    }
}
