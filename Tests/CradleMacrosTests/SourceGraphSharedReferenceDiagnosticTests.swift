//
//  SourceGraphSharedReferenceDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// shared Factory가 source graph 저장 프로퍼티를 참조하면 거부하는지 확인
@Test
func sourceGraphMacroRejectsSharedFactorySourceReference() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph {
			@Provide(.shared)
			private func makeFeature() -> Feature {
				Feature(repository: appGraph.repository)
			}
		}
		""",
		expandedSource: """
		final class FeatureGraph {
			private func makeFeature() -> Feature {
				Feature(repository: appGraph.repository)
			}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sharedSourceReference"),
				message: "`@Provide(.shared)` Factory는 `appGraph` source graph를 참조할 수 없습니다.",
				line: 5,
				column: 23,
				highlights: ["appGraph"]
			)
		],
		macros: testMacros
	)
}

// source 저장 프로퍼티의 직접 참조 위치 탐색
@Test
func sourceGraphReferenceFindsUnshadowedSourceStorage() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { Feature(repository: appGraph.repository) }"
	)

	let reference = try #require(
		sourceGraphReference(in: factory, sourceNames: ["appGraph"])
	)
	#expect(reference.text == "appGraph")
}

// Factory 매개변수와 같은 source 이름은 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresFactoryParameterShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature(appGraph: AppGraph) -> Feature { appGraph.feature }"
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}

// 지역 변수와 같은 source 이름은 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresLocalVariableShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let appGraph = LocalGraph(); return appGraph.feature }"
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}
