import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppearanceSettings {
    static let storageKey = "com.danilarahmanov.CardFlipper.appearance.accentColor"

    private struct PersistedColor: Codable {
        let red: Double
        let green: Double
        let blue: Double

        var isValid: Bool {
            [red, green, blue].allSatisfy { $0.isFinite && (0 ... 1).contains($0) }
        }
    }

    private let defaults: UserDefaults

    var accentColor: Color {
        didSet {
            persist(accentColor)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentColor = Self.restore(from: defaults) ?? Color(uiColor: .systemBlue)
    }

    var sRGBComponents: (red: Double, green: Double, blue: Double)? {
        Self.components(for: accentColor).map { ($0.red, $0.green, $0.blue) }
    }

    private func persist(_ color: Color) {
        guard
            let components = Self.components(for: color),
            let data = try? JSONEncoder().encode(components)
        else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func restore(from defaults: UserDefaults) -> Color? {
        guard
            let data = defaults.data(forKey: storageKey),
            let persisted = try? JSONDecoder().decode(PersistedColor.self, from: data),
            persisted.isValid
        else {
            return nil
        }
        return Color(
            .sRGB,
            red: persisted.red,
            green: persisted.green,
            blue: persisted.blue,
            opacity: 1
        )
    }

    private static func components(for color: Color) -> PersistedColor? {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = UIColor(color).resolvedColor(
                with: UITraitCollection(userInterfaceStyle: .light)
            ).cgColor.converted(
                to: colorSpace,
                intent: .defaultIntent,
                options: nil
            ),
            let components = converted.components,
            components.count >= 3
        else {
            return nil
        }

        let persisted = PersistedColor(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2])
        )
        return persisted.isValid ? persisted : nil
    }
}
