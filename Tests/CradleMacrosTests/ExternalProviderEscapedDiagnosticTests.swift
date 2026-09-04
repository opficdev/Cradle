//
//  ExternalProviderEscapedDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 백틱으로 감싼 인스턴스 멤버와 생성 메서드의 이름 충돌 확인
@Test(arguments: [
	"func `profile`(id: Int) -> Profile { Profile() }",
	"let `profile` = Profile()"
])
func externalProviderDiagnosticRejectsEscapedMemberName(member: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			\(member)
			@Provide(.transient)
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		expandedSource: """
		final class Graph {
			\(member)
			private func makeProfile(@External id: Int) -> Profile { Profile() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "externalMethodNameCollision"),
				message: "`profile` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다.",
				line: 5,
				column: 49,
				highlights: ["Profile"],
				notes: [
					NoteSpec(
						message: "`profile` 인스턴스 멤버가 같은 이름을 사용합니다.",
						line: 3,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}
