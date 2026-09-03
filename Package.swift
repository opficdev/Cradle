// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "Cradle",
	platforms: [.iOS(.v17), .macOS(.v10_15)],
	products: [
		.library(
			name: "Cradle",
			targets: ["Cradle"]
		),
		.library(
			name: "CradleTesting",
			targets: ["CradleTesting"]
		)
	],
	dependencies: [
		.package(
			url: "https://github.com/swiftlang/swift-syntax.git",
			from: "603.0.2"
		)
	],
	targets: [
		.macro(
			name: "CradleMacros",
			dependencies: [
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
				.product(name: "SwiftDiagnostics", package: "swift-syntax"),
				.product(name: "SwiftSyntax", package: "swift-syntax"),
				.product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax")
			]
		),
		.target(name: "Cradle", dependencies: ["CradleMacros"]),
		.target(name: "CradleTesting", dependencies: ["Cradle"]),
		.target(
			name: "CradleConsumerFixture",
			dependencies: ["Cradle"],
			path: "Tests/CradleConsumerFixture"
		),
		.testTarget(
			name: "CradleTests",
			dependencies: ["Cradle", "CradleConsumerFixture"]
		),
		.testTarget(
			name: "CradleMacrosTests",
			dependencies: [
				"CradleMacros",
				.product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
