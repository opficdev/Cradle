// swift-tools-version: 6.3

import PackageDescription

// shared graph의 compiler·Macro 실패 검증용 package
let package = Package(
	name: "SharedGraphInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "SharedGraphInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
