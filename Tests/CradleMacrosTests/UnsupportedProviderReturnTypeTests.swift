//
//  UnsupportedProviderReturnTypeTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// G1 범위 밖 반환 타입 거부 확인
@Test(arguments: ["some Service", "Service?", "[Service]", "(Service, Service)", "() -> Service"])
func dependencyGraphRejectsRemainingUnsupportedProviderReturnTypes(returnType: String) {
	// Macro 확장 입력 source
	let source = """
	@DependencyGraph
	final class Graph {
		@Provide
		private func makeService() -> \(returnType) { Service() }
	}
	"""
	// 생성 접근자가 없는 Macro 확장 결과
	let expandedSource = """
	final class Graph {
		private func makeService() -> \(returnType) { Service() }
	}
	"""

	assertMacroExpansion(
		source,
		expandedSource: expandedSource,
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` 반환 타입은 generic argument가 없는 구체 명목 타입이어야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// 본문 없는 provider 거부 확인
@Test
func dependencyGraphRejectsProviderWithoutBody() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeService() -> Service
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService() -> Service
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory는 명시적 반환 타입과 본문이 필요합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}
