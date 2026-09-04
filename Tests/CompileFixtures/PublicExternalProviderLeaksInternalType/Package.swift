// swift-tools-version: 6.3

import PackageDescription

// 외부 입력 생성 메서드의 public 타입 경계 검증용 package
let package = Package(
	name: "PublicExternalProviderLeaksInternalType",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "PublicExternalProviderLeaksInternalType",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
