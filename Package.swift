// swift-tools-version: 6.3

import PackageDescription

let package = Package(
	name: "Cradle",
	platforms: [.iOS(.v17)],
	products: [
		.library(
			name: "Cradle",
			targets: ["Cradle"]
		),
	],
	targets: [
		.target(name: "Cradle"),
		.testTarget(
			name: "CradleTests",
			dependencies: ["Cradle"]
		),
	],
	swiftLanguageModes: [.v6]
)
