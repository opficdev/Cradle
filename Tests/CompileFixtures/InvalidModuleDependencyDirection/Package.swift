// swift-tools-version: 6.3

import PackageDescription

// Domain의 역방향 import를 검증하는 compile-fail package
let package = Package(
	name: "InvalidModuleDependencyDirection",
	platforms: [.macOS(.v10_15)],
	targets: [
		.target(name: "Domain"),
		.target(name: "Data", dependencies: ["Domain"])
	],
	swiftLanguageModes: [.v6]
)
