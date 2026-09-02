//
//  CircularDependencyRegressionTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 완료된 등록을 두 경로에서 재사용하는 다이아몬드의 기존 생성 코드 보존 확인
@Test
func circularDependencyRegressionPreservesDiamondExpansion() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeA(b: B, c: C) -> A { fatalError() }
			@Provide
			private func makeB(d: D) -> B { fatalError() }
			@Provide
			private func makeC(d: D) -> C { fatalError() }
			@Provide
			private func makeD() -> D { D() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeA(b: B, c: C) -> A { fatalError() }
			private func makeB(d: D) -> B { fatalError() }
			private func makeC(d: D) -> C { fatalError() }
			private func makeD() -> D { D() }

		    internal var a: A {
		        makeA(b: b, c: c)
		    }

		    internal var b: B {
		        makeB(d: d)
		    }

		    internal var c: C {
		        makeC(d: d)
		    }

		    internal var d: D {
		        makeD()
		    }
		}
		""",
		macros: testMacros
	)
}

// 외부 레이블·백틱 이름·프로토콜 매개변수의 정상 연결 보존 확인
@Test
func circularDependencyRegressionPreservesLabelsAndProtocolParameters() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeConsumer(primary repository: any Repository, _ `default`: `default`) -> Consumer {
				fatalError()
			}
			@Provide
			private func makeRepository() -> any Repository { fatalError() }
			@Provide
			private func makeDefault() -> `default` { fatalError() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(primary repository: any Repository, _ `default`: `default`) -> Consumer {
				fatalError()
			}
			private func makeRepository() -> any Repository { fatalError() }
			private func makeDefault() -> `default` { fatalError() }

		    internal var consumer: Consumer {
		        makeConsumer(primary: repository, `default`)
		    }

		    internal var repository: any Repository {
		        makeRepository()
		    }

		    internal var `default`: `default` {
		        makeDefault()
		    }
		}
		""",
		macros: testMacros
	)
}

// 기존 문법·중복·멤버 충돌·누락 오류가 있으면 순환 검사를 생략하는지 확인
@Test
func circularDependencyRegressionPreservesProviderValidationPrecedence() {
	assertCircularDependencyPrecedence(
		member: "\t@Provide\n\tprivate func makeB(b: B = B()) -> B { B() }",
		expandedMember: "\tprivate func makeB(b: B = B()) -> B { B() }",
		diagnostic: DiagnosticSpec(
			id: .init(domain: "Cradle", id: "invalidProviderParameter"),
			message: "`@Provide` Factory 매개변수는 지원하는 형식이어야 합니다.",
			line: 5,
			column: 2
		)
	)
}

// 중복 등록 오류가 있으면 순환 검사를 생략하는지 확인
@Test
func circularDependencyRegressionPreservesDuplicateValidationPrecedence() {
	assertCircularDependencyPrecedence(
		member: "\t@Provide\n\tprivate func makeOther() -> A { A() }",
		expandedMember: "\tprivate func makeOther() -> A { A() }",
		diagnostic: DiagnosticSpec(
			id: .init(domain: "Cradle", id: "duplicateAccessor"),
			message: "`A` 등록 타입이 중복됩니다.",
			line: 4,
			column: 30,
			highlights: ["A"],
			notes: [
				NoteSpec(message: "`makeA` Factory의 등록입니다. 등록 타입은 `A`입니다.", line: 3, column: 2),
				NoteSpec(message: "`makeOther` Factory의 등록입니다. 등록 타입은 `A`입니다.", line: 5, column: 2)
			]
		)
	)
}

// 기존 멤버 충돌이 있으면 순환 검사를 생략하는지 확인
@Test
func circularDependencyRegressionPreservesMemberValidationPrecedence() {
	assertCircularDependencyPrecedence(
		member: "\tfunc a() {}",
		expandedMember: "\tfunc a() {}",
		diagnostic: DiagnosticSpec(
			id: .init(domain: "Cradle", id: "existingMemberCollision"),
			message: "생성 프로퍼티 이름이 기존 인스턴스 멤버와 충돌합니다.",
			line: 3,
			column: 2
		)
	)
}

// 누락 등록 오류가 있으면 순환 검사를 생략하는지 확인
@Test
func circularDependencyRegressionPreservesMissingValidationPrecedence() {
	assertCircularDependencyPrecedence(
		member: "\t@Provide\n\tprivate func makeB(missing: Missing) -> B { B() }",
		expandedMember: "\tprivate func makeB(missing: Missing) -> B { B() }",
		diagnostic: DiagnosticSpec(
			id: .init(domain: "Cradle", id: "missingRegistration"),
			message: "`makeB`의 매개변수 타입 `Missing`에 대응하는 등록이 없습니다.",
			line: 6,
			column: 30,
			highlights: ["Missing"],
			notes: [NoteSpec(message: "`makeB` Factory가 이 의존성을 요구합니다.", line: 5, column: 2)]
		)
	)
}

// 같은 이름을 사용하는 별개 그래프에 순환 탐색 상태가 누출되지 않는지 확인
@Test
func circularDependencyRegressionIsolatesGraphs() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class FirstGraph {
			@Provide
			private func makeA(a: A) -> A { A() }
		}
		@DependencyGraph
		final class SecondGraph {
			@Provide
			private func makeA(a: A) -> A { A() }
		}
		@DependencyGraph
		final class ValidGraph {
			@Provide
			private func makeA() -> A { A() }
		}
		""",
		expandedSource: """
		final class FirstGraph {
			private func makeA(a: A) -> A { A() }
		}
		final class SecondGraph {
			private func makeA(a: A) -> A { A() }
		}
		final class ValidGraph {
			private func makeA() -> A { A() }

		    internal var a: A {
		        makeA()
		    }
		}
		""",
		diagnostics: [4, 9].map { line in
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "circularDependency"),
				message: "`a → a` 순환 의존성이 있습니다.",
				line: line,
				column: 24,
				highlights: ["A"],
				notes: [NoteSpec(
					message: "`makeA` Factory의 등록입니다. 생성 프로퍼티는 `a`입니다.", line: line - 1, column: 2
				)]
			)
		},
		macros: testMacros
	)
}

// Factory 본문 호출과 서로 다른 타입 별칭을 의미 분석하지 않는 기존 경계 확인
@Test
func circularDependencyRegressionDoesNotInferBodyOrAliasEdges() {
	assertMacroExpansion(
		"""
		typealias First = Service
		typealias Second = Service
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst(second: Second) -> First { first() }
			@Provide
			private func makeSecond() -> Second { Service() }
		}
		""",
		expandedSource: """
		typealias First = Service
		typealias Second = Service
		final class Graph {
			private func makeFirst(second: Second) -> First { first() }
			private func makeSecond() -> Second { Service() }

		    internal var first: First {
		        makeFirst(second: second)
		    }

		    internal var second: Second {
		        makeSecond()
		    }
		}
		""",
		macros: testMacros
	)
}

// 자기 순환이 있는 등록과 함께 선언된 선행 오류의 기존 진단만 확인
private func assertCircularDependencyPrecedence(
	member: String,
	expandedMember: String,
	diagnostic: DiagnosticSpec
) {
	assertMacroExpansion(
		"@DependencyGraph\nfinal class Graph {\n\t@Provide\n"
			+ "\tprivate func makeA(a: A) -> A { A() }\n\(member)\n}",
		expandedSource: "final class Graph {\n\tprivate func makeA(a: A) -> A { A() }\n\(expandedMember)\n}",
		diagnostics: [diagnostic],
		macros: testMacros
	)
}
