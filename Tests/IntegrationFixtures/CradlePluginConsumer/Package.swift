// swift-tools-version: 6.3

import PackageDescription

// CradlePlugin Mermaid 산출물 경계를 검증하는 독립 소비자 package
let package = Package(
	name: "CradlePluginConsumer",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.target(
			name: "AppComposition",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			],
			plugins: [
				.plugin(name: "CradlePlugin", package: "Cradle")
			]
		),
		.target(
			name: "UnrelatedComposition",
			dependencies: [.product(name: "Cradle", package: "Cradle")]
		)
	],
	swiftLanguageModes: [.v6]
)
