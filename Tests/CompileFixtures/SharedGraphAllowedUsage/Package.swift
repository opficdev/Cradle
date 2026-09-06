// swift-tools-version: 6.3

import PackageDescription

// shared graph의 허용 선언과 source 정적 접근 검증용 package
let package = Package(
	name: "SharedGraphAllowedUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "SharedGraphAllowedUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
