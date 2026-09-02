// swift-tools-version: 6.3
// Created by opfic on 9/2/26.

import PackageDescription

// source 조합 graph superclass 초기화 오류 검증용 package
let package = Package(
	name: "SourceGraphSuperclass",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "SourceGraphSuperclass",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
