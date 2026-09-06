// swift-tools-version: 6.3

import PackageDescription

// lazy 수명 Macro 진단의 compiler 출력 검증용 package
let package = Package(
	name: "LazyProviderInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "LazyProviderInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
