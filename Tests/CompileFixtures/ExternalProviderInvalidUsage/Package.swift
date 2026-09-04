// swift-tools-version: 6.3

import PackageDescription

// 외부 입력 Macro 진단의 compiler 출력 검증용 package
let package = Package(
	name: "ExternalProviderInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ExternalProviderInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
