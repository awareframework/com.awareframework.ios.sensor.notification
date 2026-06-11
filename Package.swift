// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.notification",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.notification",
            targets: [
                "com.awareframework.ios.sensor.notification"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.notification",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/com.awareframework.ios.sensor.notification"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.notificationTests",
            dependencies: [
                .target(name: "com.awareframework.ios.sensor.notification")
            ],
            path: "Tests/com.awareframework.ios.sensor.notificationTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
