// swift-tools-version: 6.3

import PackageDescription

// lazy actor graph의 소비자 compiler 경계 검증용 package
let package = Package(
	name: "LazyActorGraphNonSendableBoundary",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "LazyActorGraphNonSendableBoundary",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
