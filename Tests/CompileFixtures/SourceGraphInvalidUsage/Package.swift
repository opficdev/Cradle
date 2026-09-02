// swift-tools-version: 6.3
// Created by opfic on 9/2/26.

import PackageDescription

// source graph 소비 오류를 확인할 compile-fail 검증 package
let package = Package(
	name: "SourceGraphInvalidUsage",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "SourceGraphInvalidUsage",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
