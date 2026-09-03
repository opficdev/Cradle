// swift-tools-version: 6.3

import PackageDescription

// 다중 모듈 source graph 조합을 검증하는 독립 package
let package = Package(
	name: "MultiModuleComposition",
	platforms: [.macOS(.v10_15)],
	targets: [
		.target(name: "Domain")
	],
	swiftLanguageModes: [.v6]
)
