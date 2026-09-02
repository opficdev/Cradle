//
//  ActorGraphDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/3/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// actor graph source 조합 원본 인자 위치 진단 확인
@Test
func actorDependencyGraphRejectsSources() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		actor Graph {}
		""",
		expandedSource: """
		actor Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "actorSourcesUnsupported"),
				message: "actor `@DependencyGraph`에는 `sources`를 지정할 수 없습니다.",
				line: 1,
				column: 27,
				highlights: ["[AppGraph.self]"]
			)
		],
		macros: testMacros
	)
}
