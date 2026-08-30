//
//  DuplicateRegistrationDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// 등록 이름이 달라도 오류와 보조 설명의 식별자를 유지하는지 확인
@Test(arguments: ["first", "second"])
func duplicateRegistrationKeepsMessageIdentifiersStable(name: String) {
	// 이름에 영향을 받지 않아야 하는 중복 오류
	let diagnostic = DuplicateRegistrationDiagnostic(accessorIdentifier: name)
	// 별도의 고정 식별자를 갖는 등록 위치 설명
	let note = DuplicateRegistrationProviderNote(factoryName: name, returnType: "any Domain.Repository")
	#expect(diagnostic.diagnosticID == .init(domain: "Cradle", id: "duplicateAccessor"))
	#expect(diagnostic.severity == .error)
	#expect(note.noteID == .init(domain: "Cradle", id: "duplicateAccessorProvider"))
}

// 타입·프로토콜·말단 이름·백틱 중복의 원본 위치와 후속 누락 진단 생략 확인
@Test(arguments: [
	("Service", "Service", "service"),
	("any Repository", "any Repository", "repository"),
	("First.Service", "Second.Service", "service"),
	("any First.Repository", "any Second.Repository", "repository"),
	("dependency", "`dependency`", "dependency")
])
func duplicateRegistrationReportsBothProviderLocations(first: String, second: String, accessor: String) {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst(missing: Missing) -> \(first) { fatalError() }
			@Provide
			private func makeSecond() -> \(second) { fatalError() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst(missing: Missing) -> \(first) { fatalError() }
			private func makeSecond() -> \(second) { fatalError() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "duplicateAccessor"),
				message: "`\(accessor)` 생성 접근자를 만드는 등록이 중복됩니다.",
				line: 4,
				column: 46,
				highlights: [first],
				notes: [
					NoteSpec(message: "`makeFirst` Factory의 등록입니다. 반환 타입은 `\(first)`입니다.", line: 3, column: 2),
					NoteSpec(message: "`makeSecond` Factory의 등록입니다. 반환 타입은 `\(second)`입니다.", line: 5, column: 2)
				]
			)
		],
		macros: testMacros
	)
}

// 여러 줄 반환 선언과 주석·백틱 Factory에서 반환 타입 오류와 등록 위치를 보존하는지 확인
@Test
func duplicateRegistrationHighlightsOriginalReturnType() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func `makeFirst`() ->
				/* result */ any Domain.`repository` { fatalError() }
			@Provide
			private func makeSecond() -> any repository { fatalError() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func `makeFirst`() ->
				/* result */ any Domain.`repository` { fatalError() }
			private func makeSecond() -> any repository { fatalError() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "duplicateAccessor"),
				message: "`repository` 생성 접근자를 만드는 등록이 중복됩니다.",
				line: 5,
				column: 16,
				highlights: ["any Domain.`repository`"],
				notes: [
					NoteSpec(
						message: "`makeFirst` Factory의 등록입니다. 반환 타입은 `any Domain.`repository``입니다.",
						line: 3,
						column: 2
					),
					NoteSpec(message: "`makeSecond` Factory의 등록입니다. 반환 타입은 `any repository`입니다.", line: 6, column: 2)
				]
			)
		],
		macros: testMacros
	)
}

// 세 등록 그룹과 두 등록 그룹이 엇갈려도 선언 순서대로 진단하고 정상 접근자도 생성하지 않는지 확인
@Test
func duplicateRegistrationReportsInterleavedGroupsInSourceOrder() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst() -> Zeta { .init() }
			@Provide
			private func makeSecond() -> Alpha { .init() }
			@Provide
			private func makeThird() -> Zeta { .init() }
			@Provide
			private func makeFourth() -> Alpha { .init() }
			@Provide
			private func makeFifth() -> Zeta { .init() }
			@Provide
			private func makeOther() -> Other { .init() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst() -> Zeta { .init() }
			private func makeSecond() -> Alpha { .init() }
			private func makeThird() -> Zeta { .init() }
			private func makeFourth() -> Alpha { .init() }
			private func makeFifth() -> Zeta { .init() }
			private func makeOther() -> Other { .init() }
		}
		""",
		diagnostics: interleavedGroupDiagnostics(),
		macros: testMacros
	)
}

// 문법 오류와 중복·멤버 충돌은 기존 순서로 내고 누락 의존성 진단은 생략하는지 확인
@Test
func duplicateRegistrationPreservesValidationOrder() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			func service() {}
			@Provide
			private func makeFirst(missing: Missing) -> Service { .init() }
			@Provide
			private func makeSecond() -> Service { .init() }
			@Provide
			private func makeInvalid(value: Value = Value()) -> Value { value }
			@Provide
			private func makeOther(missing: Missing) -> Other { .init() }
		}
		""",
		expandedSource: """
		final class Graph {
			func service() {}
			private func makeFirst(missing: Missing) -> Service { .init() }
			private func makeSecond() -> Service { .init() }
			private func makeInvalid(value: Value = Value()) -> Value { value }
			private func makeOther(missing: Missing) -> Other { .init() }
		}
		""",
		diagnostics: validationOrderDiagnostics(),
		macros: testMacros
	)
}

// 같은 타입을 가리키더라도 별칭의 생성 접근자 이름이 다르면 기존처럼 허용하는지 확인
@Test
func duplicateRegistrationPreservesDistinctAliasAccessors() {
	assertMacroExpansion(
		"""
		typealias FirstAlias = Service
		typealias SecondAlias = Service
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst() -> FirstAlias { .init() }
			@Provide
			private func makeSecond() -> SecondAlias { .init() }
		}
		""",
		expandedSource: """
		typealias FirstAlias = Service
		typealias SecondAlias = Service
		final class Graph {
			private func makeFirst() -> FirstAlias { .init() }
			private func makeSecond() -> SecondAlias { .init() }

		    internal func firstAlias() -> FirstAlias {
		        makeFirst()
		    }

		    internal func secondAlias() -> SecondAlias {
		        makeSecond()
		    }
		}
		""",
		macros: testMacros
	)
}

// 백틱 대문자 이름과 일반 이름이 다른 접근자를 만드는 기존 규칙 유지
@Test
func duplicateRegistrationPreservesEscapedUppercaseAccessor() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst() -> any Domain.`Repository` { fatalError() }
			@Provide
			private func makeSecond() -> any Repository { fatalError() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst() -> any Domain.`Repository` { fatalError() }
			private func makeSecond() -> any Repository { fatalError() }

		    internal func `Repository`() -> any Domain.`Repository` {
		        makeFirst()
		    }

		    internal func repository() -> any Repository {
		        makeSecond()
		    }
		}
		""",
		macros: testMacros
	)
}

// 엇갈린 두 충돌 그룹의 원본 위치와 선언 순서 기대값
private func interleavedGroupDiagnostics() -> [DiagnosticSpec] {
	[
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "duplicateAccessor"),
			message: "`zeta` 생성 접근자를 만드는 등록이 중복됩니다.",
			line: 4,
			column: 30,
			highlights: ["Zeta"],
			notes: [
				NoteSpec(message: "`makeFirst` Factory의 등록입니다. 반환 타입은 `Zeta`입니다.", line: 3, column: 2),
				NoteSpec(message: "`makeThird` Factory의 등록입니다. 반환 타입은 `Zeta`입니다.", line: 7, column: 2),
				NoteSpec(message: "`makeFifth` Factory의 등록입니다. 반환 타입은 `Zeta`입니다.", line: 11, column: 2)
			]
		),
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "duplicateAccessor"),
			message: "`alpha` 생성 접근자를 만드는 등록이 중복됩니다.",
			line: 6,
			column: 31,
			highlights: ["Alpha"],
			notes: [
				NoteSpec(message: "`makeSecond` Factory의 등록입니다. 반환 타입은 `Alpha`입니다.", line: 5, column: 2),
				NoteSpec(message: "`makeFourth` Factory의 등록입니다. 반환 타입은 `Alpha`입니다.", line: 9, column: 2)
			]
		)
	]
}

// 문법 오류 뒤에 중복·멤버 충돌을 출력하는 기존 순서 기대값
private func validationOrderDiagnostics() -> [DiagnosticSpec] {
	[
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "invalidProviderParameter"),
			message: "`@Provide` factory 매개변수는 지원 형식이어야 하며 지역 이름이 "
				+ "등록 생성 접근자와 일치해야 합니다.",
			line: 8,
			column: 2
		),
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "duplicateAccessor"),
			message: "`service` 생성 접근자를 만드는 등록이 중복됩니다.",
			line: 5,
			column: 46,
			highlights: ["Service"],
			notes: [
				NoteSpec(message: "`makeFirst` Factory의 등록입니다. 반환 타입은 `Service`입니다.", line: 4, column: 2),
				NoteSpec(message: "`makeSecond` Factory의 등록입니다. 반환 타입은 `Service`입니다.", line: 6, column: 2)
			]
		),
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "existingMemberCollision"),
			message: "생성 접근자 이름이 기존 instance member와 충돌합니다.",
			line: 4,
			column: 2
		),
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "existingMemberCollision"),
			message: "생성 접근자 이름이 기존 instance member와 충돌합니다.",
			line: 6,
			column: 2
		)
	]
}
