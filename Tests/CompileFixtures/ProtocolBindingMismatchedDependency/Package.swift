// swift-tools-version: 6.3
// Created by opfic on 8/30/26.

import PackageDescription

// 이름 연결 후 프로토콜 타입 불일치의 컴파일 실패 검증용 package
let package = Package(
	name: "ProtocolBindingMismatchedDependency",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "ProtocolBindingMismatchedDependency",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
