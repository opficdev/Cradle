// swift-tools-version: 6.3
// Created by opfic on 9/2/26.

import PackageDescription

// 본문 없는 추상 반환 Factory의 컴파일 실패 검증용 package
let package = Package(
	name: "BodylessAbstractProvider",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "BodylessAbstractProvider",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
