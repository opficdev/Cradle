//
//  ExternalAttributeTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 다른 module의 같은 마지막 이름을 외부 입력으로 오인하지 않는지 확인
@Test
func externalProviderDiagnosticDoesNotRecognizeOtherExternal() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeService(@Other.External input: Int) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(@Other.External input: Int) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeService`의 매개변수 타입 `Int`에 대응하는 등록이 없습니다.",
				line: 4,
				column: 50,
				highlights: ["Int"],
				notes: [
					NoteSpec(
						message: "`makeService` Factory가 이 의존성을 요구합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}
