//
//  ProtocolBindingDiagnosticsTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 타입이 같아도 지역 이름이 다른 등록을 선택하지 않는지 확인
@Test
func protocolBindingRejectsMissingAccessor() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeConsumer(missing: any Repository) -> Consumer { Consumer() }
			@Provide
			private func makeRepository() -> any Repository { LiveRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(missing: any Repository) -> Consumer { Consumer() }
			private func makeRepository() -> any Repository { LiveRepository() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeConsumer`의 매개변수 `missing`에 대응하는 등록이 없습니다.",
				line: 4,
				column: 28,
				highlights: ["missing"],
				notes: [NoteSpec(message: "`makeConsumer` Factory가 이 의존성을 요구합니다.", line: 3, column: 2)]
			)
		],
		macros: testMacros
	)
}

// 프로토콜 경로가 달라도 접근자 이름이 겹치면 거부하는지 확인
@Test
func protocolBindingRejectsDuplicateAccessors() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst() -> any Repository { LiveRepository() }
			@Provide
			private func makeSecond() -> any Domain.Repository { OtherRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst() -> any Repository { LiveRepository() }
			private func makeSecond() -> any Domain.Repository { OtherRepository() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "duplicateAccessor"),
				message: "`repository` 생성 접근자를 만드는 등록이 중복됩니다.",
				line: 4,
				column: 30,
				highlights: ["any Repository"],
				notes: [
					NoteSpec(message: "`makeFirst` Factory의 등록입니다. 반환 타입은 `any Repository`입니다.", line: 3, column: 2),
					NoteSpec(
						message: "`makeSecond` Factory의 등록입니다. 반환 타입은 `any Domain.Repository`입니다.",
						line: 5,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// 기존 인스턴스 멤버와 프로토콜 접근자 이름의 충돌 확인
@Test
func protocolBindingRejectsMemberCollision() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			func repository() {}
			@Provide
			private func makeRepository() -> any Repository { LiveRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			func repository() {}
			private func makeRepository() -> any Repository { LiveRepository() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "existingMemberCollision"),
				message: "생성 접근자 이름이 기존 instance member와 충돌합니다.",
				line: 4,
				column: 2
			)
		],
		macros: testMacros
	)
}
