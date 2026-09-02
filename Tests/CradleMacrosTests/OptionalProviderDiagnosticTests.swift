//
//  OptionalProviderDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 반환 타입의 직접 Optional 문법 진단 확인
@Test(arguments: ["Service?", "Optional<Service>", "Swift.Optional<Service>"])
func optionalProviderDiagnosticRejectsReturnType(type: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func provideService() -> \(type) { nil }
		}
		""",
		expandedSource: """
		final class Graph {
			private func provideService() -> \(type) { nil }
		}
		""",
		diagnostics: [invalidProviderTypeDiagnostic(line: 4, column: 35, type: type)],
		macros: testMacros
	)
}

// provider 매개변수의 직접 Optional 문법 진단 확인
@Test
func optionalProviderDiagnosticRejectsParameterType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func provideFeature(service: Service?) -> Feature { Feature() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func provideFeature(service: Service?) -> Feature { Feature() }
		}
		""",
		diagnostics: [invalidProviderTypeDiagnostic(line: 4, column: 39, type: "Service?")],
		macros: testMacros
	)
}

// Optional 오류의 식별자·문구·강조 범위
private func invalidProviderTypeDiagnostic(line: Int, column: Int, type: String) -> DiagnosticSpec {
	DiagnosticSpec(
		id: .init(domain: "Cradle", id: "invalidProviderType"),
		message: "`@Provide`의 반환 타입과 매개변수 타입에는 Optional을 사용할 수 없습니다.",
		line: line,
		column: column,
		highlights: [type]
	)
}
