import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
protocol AppIconClient {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func changeIcon(to name: String?) async throws
}

private struct SystemAppIconClient: AppIconClient {
    var supportsAlternateIcons: Bool { UIApplication.shared.supportsAlternateIcons }
    var alternateIconName: String? { UIApplication.shared.alternateIconName }

    func changeIcon(to name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}

@MainActor
@Observable
final class AppIconSettings {
    enum AppIcon: String, CaseIterable, Identifiable {
        case `default`
        case violet3D = "IconViolet3D"
        case orange3D = "IconOrange3D"
        case mint3D = "IconMint3D"
        case midnight3D = "IconMidnight3D"
        case origami = "IconOrigami"
        case pixel = "IconPixel"
        case owl = "IconOwl"
        case monogram = "IconMonogram"
        case orbit = "IconOrbit"

        var id: String { rawValue }
        var alternateIconName: String? { self == .default ? nil : rawValue }
        var previewAssetName: String { "Preview_\(self == .default ? "AppIcon" : rawValue)" }
        var titleKey: LocalizedStringKey {
            switch self {
            case .default: "settings.icon.default"
            case .violet3D: "settings.icon.IconViolet3D"
            case .orange3D: "settings.icon.IconOrange3D"
            case .mint3D: "settings.icon.IconMint3D"
            case .midnight3D: "settings.icon.IconMidnight3D"
            case .origami: "settings.icon.IconOrigami"
            case .pixel: "settings.icon.IconPixel"
            case .owl: "settings.icon.IconOwl"
            case .monogram: "settings.icon.IconMonogram"
            case .orbit: "settings.icon.IconOrbit"
            }
        }
        var accessibilityIdentifier: String { "settings.icon.\(rawValue)" }
    }

    private let client: any AppIconClient
    private(set) var selectedIcon: AppIcon
    private(set) var pendingIcon: AppIcon?
    var errorMessage: String?
    var isChanging: Bool { pendingIcon != nil }
    var supportsAlternateIcons: Bool { client.supportsAlternateIcons }

    init(client: (any AppIconClient)? = nil) {
        let client = client ?? SystemAppIconClient()
        self.client = client
        selectedIcon = client.alternateIconName.flatMap(AppIcon.init(rawValue:)) ?? .default
    }

    func refreshSelection() {
        guard !isChanging else { return }
        selectedIcon = client.alternateIconName.flatMap(AppIcon.init(rawValue:)) ?? .default
    }

    func select(_ icon: AppIcon) async {
        guard !isChanging else { return }
        refreshSelection()
        guard icon != selectedIcon else { return }
        guard supportsAlternateIcons else {
            errorMessage = String(localized: "settings.icon.unsupported")
            return
        }

        pendingIcon = icon
        errorMessage = nil
        defer {
            pendingIcon = nil
            refreshSelection()
        }
        do {
            try await client.changeIcon(to: icon.alternateIconName)
        } catch {
            errorMessage = String(localized: "settings.icon.error.message")
        }
    }
}
