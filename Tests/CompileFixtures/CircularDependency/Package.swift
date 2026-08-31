// swift-tools-version: 6.3
// Created by opfic on 8/30/26.

import PackageDescription

// 순환 의존성의 원본 오류와 보조 설명을 검증하는 패키지
let package = Package(
	name: "CircularDependency",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "CircularDependency",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
