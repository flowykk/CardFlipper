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
        .target(
            name: "StatisticsFeature",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.danilarahmanov.CardFlipper.StatisticsFeature",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/StatisticsFeature/**"],
            resources: ["Resources/StatisticsFeature/**"],
            dependencies: [.target(name: "Core")]
        ),
        .target(
            name: "StudyTimerWidgetExtension",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.danilarahmanov.CardFlipper.StudyTimerWidget",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            sources: ["Sources/StudyTimerWidget/**"],
            dependencies: [.target(name: "StatisticsFeature")]
        ),
        .app(
            name: "CardFlipper",
            bundleId: "com.danilarahmanov.CardFlipper",
            dependencies: ["Core", "Data", "DesignSystem", "LibraryFeature", "CardEditorFeature", "StudyFeature", "StatisticsFeature", "StudyTimerWidgetExtension"]
        ),
        .tests(name: "CoreTests", host: "Core"),
        .tests(name: "DataTests", host: "Data"),
        .tests(name: "LibraryFeatureTests", host: "LibraryFeature"),
        .tests(name: "CardEditorFeatureTests", host: "CardEditorFeature"),
        .tests(name: "StudyFeatureTests", host: "StudyFeature"),
        .tests(name: "StatisticsFeatureTests", host: "StatisticsFeature"),
        .tests(
            name: "CardFlipperAppTests",
            host: "CardFlipper",
            dependencies: ["Core", "Data", "LibraryFeature", "StudyFeature", "StatisticsFeature"]
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
                "StatisticsFeatureTests",
                "CardFlipperAppTests",
                "CardFlipperUITests",
            ])
        ),
    ]
)
