// swift-tools-version: 6.3

import PackageDescription

// actor 경계의 non-Sendable 반환 검증용 package
let package = Package(
	name: "ActorGraphNonSendableBoundary",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ActorGraphNonSendableBoundary",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
