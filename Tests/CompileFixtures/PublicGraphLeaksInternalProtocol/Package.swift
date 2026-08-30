// swift-tools-version: 6.3
// Created by opfic on 8/30/26.

import PackageDescription

// 공개 접근자의 비공개 프로토콜 노출 실패 검증용 package
let package = Package(
	name: "PublicGraphLeaksInternalProtocol",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "PublicGraphLeaksInternalProtocol",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
