// swift-tools-version: 6.3
// Created by opfic on 8/30/26.

import PackageDescription

// 누락 provider 연결의 compile-fail 검증용 package
let package = Package(
	name: "MissingProviderDependency",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "MissingProviderDependency",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
