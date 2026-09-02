//
//  UnsupportedProviderReturnTypeTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 명목 타입과 단일 프로토콜 외 반환 문법 거부 확인
@Test(arguments: [
	"some Service", "[Service]", "(Service, Service)", "() -> Service",
	"any Service & OtherService", "[any Service]", "any Service.Type", "(any Service).Type"
])
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
				id: .init(domain: "Cradle", id: "unsupportedProviderResult"),
				message: "`@Provide` 반환 타입은 프로퍼티 이름을 만들 수 있는 명목 타입 또는 `any`로 표시한 단일 프로토콜 타입이어야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}

// 명시적으로 합성한 프로토콜 반환 타입 거부 확인
@Test
func dependencyGraphRejectsProtocolCompositionReturnType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeService() -> any Service & OtherService { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService() -> any Service & OtherService { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "unsupportedProviderResult"),
				message: "`@Provide` 반환 타입은 프로퍼티 이름을 만들 수 있는 명목 타입 또는 `any`로 표시한 단일 프로토콜 타입이어야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}
