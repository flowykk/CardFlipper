import DesignSystem
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppearanceSettings {
    static let storageKey = "com.danilarahmanov.CardFlipper.appearance.accentColor"
    static let selectionKey = "com.danilarahmanov.CardFlipper.appearance.accent"

    private struct PersistedColor: Codable {
        let red: Double
        let green: Double
        let blue: Double

        var isValid: Bool {
            [red, green, blue].allSatisfy { $0.isFinite && (0 ... 1).contains($0) }
        }
    }

    private let defaults: UserDefaults

    private(set) var selectedAccent: AccessibleAccent {
        didSet {
            defaults.set(selectedAccent.id, forKey: Self.selectionKey)
        }
    }

    var accentColor: Color { selectedAccent.adaptiveColor }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let id = defaults.string(forKey: Self.selectionKey),
            let saved = AccessibleAccent.all.first(where: { $0.id == id })
        {
            selectedAccent = saved
        } else if let legacy = Self.restore(from: defaults) {
            selectedAccent = Self.nearestAccent(to: legacy)
            defaults.set(selectedAccent.id, forKey: Self.selectionKey)
        } else {
            selectedAccent = AccessibleAccent.all[0]
        }
    }

    func selectAccent(id: String) {
        guard let accent = AccessibleAccent.all.first(where: { $0.id == id }) else { return }
        selectedAccent = accent
    }

    var sRGBComponents: (red: Double, green: Double, blue: Double)? {
        Self.components(for: selectedAccent.lightColor).map { ($0.red, $0.green, $0.blue) }
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

    private static func nearestAccent(to legacy: Color) -> AccessibleAccent {
        guard let legacy = components(for: legacy) else { return AccessibleAccent.all[0] }
        return AccessibleAccent.all.min { lhs, rhs in
            distance(from: legacy, to: lhs.lightColor) < distance(from: legacy, to: rhs.lightColor)
        } ?? AccessibleAccent.all[0]
    }

    private static func distance(from legacy: PersistedColor, to color: Color) -> Double {
        guard let candidate = components(for: color) else { return .infinity }
        return pow(legacy.red - candidate.red, 2)
            + pow(legacy.green - candidate.green, 2)
            + pow(legacy.blue - candidate.blue, 2)
    }
}
