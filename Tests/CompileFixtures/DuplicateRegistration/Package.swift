// swift-tools-version: 6.3
// Created by opfic on 8/30/26.

import PackageDescription

// 중복 등록의 원본 오류와 보조 설명을 검증하는 패키지
let package = Package(
	name: "DuplicateRegistration",
	platforms: [.macOS(.v10_15)],
	dependencies: [
		.package(path: "../../..")
	],
	targets: [
		.executableTarget(
			name: "DuplicateRegistration",
			dependencies: [
				.product(name: "Cradle", package: "Cradle")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
