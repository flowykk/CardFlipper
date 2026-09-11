import SwiftUI
import UIKit

public struct AccessibleAccent: Identifiable, Equatable, Sendable {
    public let id: String
    public let lightColor: Color
    public let darkColor: Color

    public init(id: String, lightColor: Color, darkColor: Color) {
        self.id = id
        self.lightColor = lightColor
        self.darkColor = darkColor
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    public static let all: [Self] = [
        .init(id: "system", light: 0x0068D9, dark: 0x409CFF),
        .init(id: "indigo", light: 0x4B3CC4, dark: 0x9A8CFF),
        .init(id: "berry", light: 0xAD004A, dark: 0xFF78A5),
        .init(id: "forest", light: 0x006B4F, dark: 0x4FD6A5),
        .init(id: "amber", light: 0x8A4B00, dark: 0xFFB84D),
    ]

    public var adaptiveColor: Color {
        let light = UIColor(lightColor)
        let dark = UIColor(darkColor)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    public func color(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkColor : lightColor
    }

    public func preferredForegroundColor(for scheme: ColorScheme) -> Color {
        Self.preferredForegroundColor(over: color(for: scheme), scheme: scheme)
    }

    public func preferredForegroundContrastRatio(for scheme: ColorScheme) -> Double {
        let background = Self.relativeLuminance(of: color(for: scheme), scheme: scheme)
        return max(Self.contrastRatio(background, 0), Self.contrastRatio(background, 1))
    }

    public static func preferredForegroundColor(
        over background: Color,
        scheme: ColorScheme
    ) -> Color {
        let luminance = relativeLuminance(of: background, scheme: scheme)
        return contrastRatio(luminance, 0) >= contrastRatio(luminance, 1) ? .black : .white
    }

    private init(id: String, light: UInt32, dark: UInt32) {
        self.init(id: id, lightColor: Self.color(hex: light), darkColor: Self.color(hex: dark))
    }

    private static func color(hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    private static func relativeLuminance(of color: Color, scheme: ColorScheme) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: traits)
        guard let components = resolved.cgColor.components else { return 0 }
        let red: Double
        let green: Double
        let blue: Double
        if components.count == 2 {
            red = Double(components[0])
            green = red
            blue = red
        } else {
            red = Double(components[0])
            green = Double(components[1])
            blue = Double(components[2])
        }
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static func contrastRatio(_ lhs: Double, _ rhs: Double) -> Double {
        (max(lhs, rhs) + 0.05) / (min(lhs, rhs) + 0.05)
    }
}
