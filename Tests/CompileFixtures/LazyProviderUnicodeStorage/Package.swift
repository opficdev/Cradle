// swift-tools-version: 6.3

import PackageDescription

// Unicode 반환 타입의 lazy 저장소 이름 검증용 package
let package = Package(
	name: "LazyProviderUnicodeStorage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "LazyProviderUnicodeStorage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
