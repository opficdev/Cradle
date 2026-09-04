// swift-tools-version: 6.3

import PackageDescription

// 외부 입력 override Factory 형식 검증용 package
let package = Package(
	name: "ExternalProviderOverrideInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ExternalProviderOverrideInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
