//
//  ProtocolBindingDiagnosticsTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 지역 이름과 무관하게 같은 등록 타입을 연결하는지 확인
@Test
func protocolBindingConnectsMatchingRegistrationType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeConsumer(missing: any Repository) -> Consumer { Consumer() }
			@Provide(.transient)
			private func makeRepository() -> any Repository { LiveRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(missing: any Repository) -> Consumer { Consumer() }
			private func makeRepository() -> any Repository { LiveRepository() }

		    internal var consumer: Consumer {
		        makeConsumer(missing: repository)
		    }

		    internal var repository: any Repository {
		        makeRepository()
		    }
		}
		""",
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
			@Provide(.transient)
			private func makeFirst() -> any Repository { LiveRepository() }
			@Provide(.transient)
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
				message: "`repository` 생성 프로퍼티를 만드는 등록이 중복됩니다.",
				line: 4,
				column: 30,
				highlights: ["any Repository"],
				notes: [
					NoteSpec(message: "`makeFirst` Factory의 등록입니다. 등록 타입은 `any Repository`입니다.", line: 3, column: 2),
					NoteSpec(
						message: "`makeSecond` Factory의 등록입니다. 등록 타입은 `any Domain.Repository`입니다.",
						line: 5,
						column: 2
					)
				]
			)
		],
		macros: testMacros
	)
}

// bare protocol과 `any` 표기의 같은 등록 타입을 중복으로 거부하는지 확인
@Test
func protocolBindingRejectsEquivalentBareAndExistentialRegistrations() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeFirst() -> Repository { LiveRepository() }
			@Provide(.transient)
			private func makeSecond() -> any Repository { OtherRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst() -> Repository { LiveRepository() }
			private func makeSecond() -> any Repository { OtherRepository() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "duplicateAccessor"),
				message: "`Repository` 등록 타입이 중복됩니다.",
				line: 4,
				column: 30,
				highlights: ["Repository"],
				notes: [
					NoteSpec(message: "`makeFirst` Factory의 등록입니다. 등록 타입은 `Repository`입니다.", line: 3, column: 2),
					NoteSpec(message: "`makeSecond` Factory의 등록입니다. 등록 타입은 `any Repository`입니다.", line: 5, column: 2)
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
			@Provide(.transient)
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
				message: "생성 프로퍼티 이름이 기존 인스턴스 멤버와 충돌합니다.",
				line: 4,
				column: 2
			)
		],
		macros: testMacros
	)
}
