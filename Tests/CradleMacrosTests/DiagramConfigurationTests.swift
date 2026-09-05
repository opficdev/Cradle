//
//  DiagramConfigurationTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// Mermaid 산출물 표식이 Macro 확장을 바꾸지 않는지 확인
@Test(arguments: ["true", "false"])
func diagramConfigurationDoesNotChangeExpansion(value: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph(diagram: \(value))
		final class Graph {}
		""",
		expandedSource: """
		final class Graph {}
		""",
		macros: testMacros
	)
}

// Mermaid 산출물 표식의 직접 Bool literal 제약 진단 확인
@Test
func diagramConfigurationRejectsNonliteralValue() {
	assertMacroExpansion(
		"""
		@DependencyGraph(diagram: enabled)
		final class Graph {}
		""",
		expandedSource: """
		final class Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidDiagramConfiguration"),
				message: "`diagram`은 직접 작성한 `true` 또는 `false`여야 합니다.",
				line: 1,
				column: 27,
				highlights: ["enabled"]
			)
		],
		macros: testMacros
	)
}
