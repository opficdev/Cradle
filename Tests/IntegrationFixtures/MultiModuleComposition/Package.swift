// swift-tools-version: 6.3

import PackageDescription

// 다중 모듈 source graph 조합을 검증하는 독립 package
let package = Package(
	name: "MultiModuleComposition",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.target(name: "Domain"),
		.target(
			name: "Persistence",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		),
		.target(
			name: "Infra",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		),
		.target(
			name: "Data",
			dependencies: [
				.product(name: "Cradle", package: "Cradle"),
				"Domain",
				"Persistence",
				"Infra"
			]
		)
	],
	swiftLanguageModes: [.v6]
)
