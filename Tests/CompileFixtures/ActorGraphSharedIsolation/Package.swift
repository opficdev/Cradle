// swift-tools-version: 6.3

import PackageDescription

// shared Factory actor 상태 참조 검증용 package
let package = Package(
	name: "ActorGraphSharedIsolation",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ActorGraphSharedIsolation",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
