// swift-tools-version: 6.3

import PackageDescription

// CradleTesting mock의 Swift compiler 실패 검증용 package
let package = Package(
	name: "CradleTestingInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "CradleTestingInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle"),
				.product(name: "CradleTesting", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
