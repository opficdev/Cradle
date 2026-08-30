//
//  ProviderParameterDiagnosticsTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 지원하지 않는 provider 매개변수 형식 거부 확인
@Test(arguments: [
	"service: Service = Service()",
	"services: Service...",
	"service: inout Service",
	"_ _: Service",
	"service: some Service",
	"services: [some Service]"
])
func providerParameterDiagnosticsRejectUnsupportedSyntax(parameter: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeService(\(parameter)) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(\(parameter)) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "`@Provide` factory 매개변수는 지원 형식이어야 하며 지역 이름이 "
					+ "등록 생성 접근자와 일치해야 합니다.",
				line: 3,
				column: 2
			)
		],
		macros: testMacros
	)
}
