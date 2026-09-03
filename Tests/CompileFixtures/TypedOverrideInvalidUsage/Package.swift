// swift-tools-version: 6.3

import PackageDescription

// 타입 지정 override의 Swift compiler 실패 검증용 package
let package = Package(
	name: "TypedOverrideInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "TypedOverrideInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
