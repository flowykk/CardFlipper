import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "CardFlipper",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "6.0",
            "TARGETED_DEVICE_FAMILY": "1",
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release"),
        ]
    ),
    targets: [
        .framework(name: "Core"),
        .framework(name: "Data", dependencies: [.target(name: "Core")]),
        .framework(name: "DesignSystem"),
        .framework(name: "LibraryFeature", dependencies: [.target(name: "Core"), .target(name: "DesignSystem")]),
        .framework(name: "CardEditorFeature", dependencies: [.target(name: "Core"), .target(name: "DesignSystem")]),
        .framework(name: "StudyFeature", dependencies: [.target(name: "Core"), .target(name: "DesignSystem")]),
        .app(
            name: "CardFlipper",
            bundleId: "com.danilarahmanov.CardFlipper",
            dependencies: ["Core", "Data", "DesignSystem", "LibraryFeature", "CardEditorFeature", "StudyFeature"]
        ),
        .tests(name: "CoreTests", host: "Core"),
        .tests(name: "DataTests", host: "Data"),
        .tests(name: "LibraryFeatureTests", host: "LibraryFeature"),
        .tests(name: "CardEditorFeatureTests", host: "CardEditorFeature"),
        .tests(name: "StudyFeatureTests", host: "StudyFeature"),
        .tests(
            name: "CardFlipperAppTests",
            host: "CardFlipper",
            dependencies: ["Core", "Data", "LibraryFeature", "StudyFeature"]
        ),
        .uiTests(name: "CardFlipperUITests", host: "CardFlipper"),
    ],
    schemes: [
        .scheme(
            name: "CardFlipper",
            shared: true,
            buildAction: .buildAction(targets: ["CardFlipper"]),
            testAction: .targets([
                "CoreTests",
                "DataTests",
                "LibraryFeatureTests",
                "CardEditorFeatureTests",
                "StudyFeatureTests",
                "CardFlipperAppTests",
                "CardFlipperUITests",
            ])
        ),
    ]
)
