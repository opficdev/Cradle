// swift-tools-version: 6.3
// Created by opfic on 8/30/26.

import PackageDescription

// 프로토콜 미준수 반환의 컴파일 실패 검증용 package
let package = Package(
	name: "ProtocolBindingNonconformingImplementation",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ProtocolBindingNonconformingImplementation",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
