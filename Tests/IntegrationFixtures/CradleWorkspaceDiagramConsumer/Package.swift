// swift-tools-version: 6.3

import PackageDescription

let package = Package(
	name: "CradleWorkspaceDiagramConsumer",
	platforms: [.macOS(.v10_15)],
	dependencies: [.package(path: "../../..")],
	targets: [
		.target(name: "Domain", dependencies: [.product(name: "Cradle", package: "Cradle")]),
		.target(name: "Infra", dependencies: [.product(name: "Cradle", package: "Cradle")]),
		.target(name: "Data", dependencies: [.product(name: "Cradle", package: "Cradle"), "Domain", "Infra"]),
		.target(name: "AppComposition", dependencies: [.product(name: "Cradle", package: "Cradle"), "Domain", "Data", "Infra"])
	],
	swiftLanguageModes: [.v6]
)
