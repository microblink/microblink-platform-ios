// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicroblinkPlatform",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MicroblinkPlatform",
            targets: ["MicroblinkPlatform"]
        ),
        .library(
            name: "MicroblinkPlatformEngine",
            targets: ["MicroblinkPlatformEngine"]
        ),
        .library(
            name: "BlinkIDVerifyUX",
            targets: ["BlinkIDVerifyUX"]
        ),
        .library(
            name: "BlinkIDVerify",
            targets: ["BlinkIDVerify"]
        ),
        .library(
            name: "BlinkCardUX",
            targets: ["BlinkCardUX"]
        ),
        .library(
            name: "BlinkCard",
            targets: ["BlinkCard"]
        ),
        .library(
            name: "BiometricsSDK",
            targets: ["BiometricsSDK"]
        ),
        .library(
            name: "BiometricsEngine",
            targets: ["BiometricsEngine"]
        )
        
    ],
    targets: [
        .binaryTarget(
            name: "MicroblinkPlatform",
            path: "Frameworks/MicroblinkPlatform.xcframework"
        ),
        .binaryTarget(
            name: "MicroblinkPlatformEngine",
            path: "Frameworks/MicroblinkPlatformEngine.xcframework"
        ),
        .binaryTarget(
            name: "BlinkIDVerifyUX",
            url:"https://github.com/microblink/blinkid-verify-ios/releases/download/v4000.0.3/BlinkIDVerifyUX.xcframework.zip",
            checksum:"c4549ce7fe4f88f4beb6030857db841fc1b25450da05ebeb5b1231466923139e"
        ),
        .binaryTarget(
            name: "BlinkIDVerify",
            url:"https://github.com/microblink/blinkid-verify-ios/releases/download/v4000.0.3/BlinkIDVerify.xcframework.zip",
            checksum:"e1e192de8ac5e9c2393fef70e86ac38bf13c4b3ea7a6bacbf0f27433f2247315"
        ),
        .binaryTarget(
            name: "BlinkCardUX",
            url:"https://github.com/microblink/blinkcard-ios/releases/download/v3001.0.2/BlinkCardUX.xcframework.zip",
            checksum:"e8165435ec40d184ff89d470d9b019db6c85c59f1854c71a01e4816aef59d6f2"
        ),
        .binaryTarget(
            name: "BlinkCard",
            url:"https://github.com/microblink/blinkcard-ios/releases/download/v3001.0.2/BlinkCard.xcframework.zip",
            checksum:"7839f453128987914e9318b9b532a51af573d540d1b779d0c970821a6d5dff55"
        ),
        .binaryTarget(
            name: "BiometricsSDK",
            path: "Frameworks/BiometricsSDK.xcframework"
        ),
        .binaryTarget(
            name: "BiometricsEngine",
            path: "Frameworks/BiometricsEngine.xcframework"
        )
    ]
)
