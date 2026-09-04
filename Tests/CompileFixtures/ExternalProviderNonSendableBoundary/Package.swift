// swift-tools-version: 6.3

import PackageDescription

// 외부 입력 생성 메서드의 actor 경계 검증용 package
let package = Package(
	name: "ExternalProviderNonSendableBoundary",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ExternalProviderNonSendableInputBoundary",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		),
		.executableTarget(
			name: "ExternalProviderNonSendableResultBoundary",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		),
		.executableTarget(
			name: "ExternalProviderNonSendableCapture",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
