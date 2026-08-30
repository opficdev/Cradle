//
//  MissingRegistrationDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// 보조 설명의 식별자가 Factory 이름에 따라 바뀌지 않는지 확인
@Test(arguments: ["makeFirst", "`makeSecond`"])
func missingRegistrationKeepsProviderNoteIdentifierStable(factoryName: String) {
	// 매크로 확장 검사에서 직접 확인할 수 없는 보조 설명 식별자
	let note = MissingRegistrationProviderNote(factoryName: factoryName)
	#expect(note.noteID == .init(domain: "Cradle", id: "missingRegistrationProvider"))
}

// 외부 레이블과 백틱 표기에 관계없이 원본 지역 이름에 누락 오류 표시
@Test
func missingRegistrationHighlightsLocalName() {
	// 매개변수 원문, 지역 이름, 열과 강조할 원본 토큰
	let parameters = [
		("dependency: Dependency", "dependency", 3, "dependency"),
		("value dependency: Dependency", "dependency", 9, "dependency"),
		("_ dependency: Dependency", "dependency", 5, "dependency"),
		("value `dependency`: Dependency", "dependency", 9, "`dependency`"),
		("value /* label */ dependency: Dependency", "dependency", 21, "dependency"),
		("_ `default`: Dependency", "default", 5, "`default`")
	]

	for (parameter, name, column, highlight) in parameters {
		assertMacroExpansion(
			"""
			@DependencyGraph
			final class Graph {
				@Provide
				private func makeService(
					\(parameter)
				) -> Service { Service() }
			}
			""",
			expandedSource: """
			final class Graph {
				private func makeService(
					\(parameter)
				) -> Service { Service() }
			}
			""",
			diagnostics: [
				DiagnosticSpec(
					id: .init(domain: "Cradle", id: "missingRegistration"),
					message: "`makeService`의 매개변수 `\(name)`에 대응하는 등록이 없습니다.",
					line: 5,
					column: column,
					highlights: [highlight],
					notes: [
						NoteSpec(message: "`makeService` Factory가 이 의존성을 요구합니다.", line: 3, column: 2)
					]
				)
			],
			macros: testMacros
		)
	}
}

// 여러 누락과 같은 이름의 재사용을 Factory·매개변수 선언 순서대로 진단
@Test
func missingRegistrationReportsEachUseInSourceOrder() {
	// Factory·지역 이름·오류 행·보조 설명 행의 기대 순서
	let diagnostics = [
		("makeFirst", "zDependency", 5, 3),
		("makeFirst", "aDependency", 6, 3),
		("makeSecond", "zDependency", 10, 8)
	].map { factory, name, line, providerLine in
		DiagnosticSpec(
			id: .init(domain: "Cradle", id: "missingRegistration"),
			message: "`\(factory)`의 매개변수 `\(name)`에 대응하는 등록이 없습니다.",
			line: line,
			column: 3,
			highlights: [name],
			notes: [NoteSpec(message: "`\(factory)` Factory가 이 의존성을 요구합니다.", line: providerLine, column: 2)]
		)
	}

	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst(
				zDependency: Dependency,
				aDependency: Dependency
			) -> First { First() }
			@Provide
			private func makeSecond(
				zDependency: Dependency
			) -> Second { Second() }
			@Provide
			private func makeOther() -> Other { Other() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst(
				zDependency: Dependency,
				aDependency: Dependency
			) -> First { First() }
			private func makeSecond(
				zDependency: Dependency
			) -> Second { Second() }
			private func makeOther() -> Other { Other() }
		}
		""",
		diagnostics: diagnostics,
		macros: testMacros
	)
}

// 선행 매개변수 형식 오류가 있으면 다른 Factory의 누락 검사도 생략
@Test
func missingRegistrationPreservesParameterValidationPrecedence() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeService(dependency: Dependency) -> Service { Service() }
			@Provide
			private func makeOther(value: Value = Value()) -> Other { Other() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeService(dependency: Dependency) -> Service { Service() }
			private func makeOther(value: Value = Value()) -> Other { Other() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidProviderParameter"),
				message: "`@Provide` factory 매개변수는 지원 형식이어야 하며 지역 이름이 "
					+ "등록 생성 접근자와 일치해야 합니다.",
				line: 5,
				column: 2
			)
		],
		macros: testMacros
	)
}

// 접근자 충돌이 있으면 누락 진단을 추가하지 않는 기존 검증 순서 유지
@Test
func missingRegistrationPreservesAccessorValidationPrecedence() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			func service() {}
			@Provide
			private func makeService(dependency: Dependency) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			func service() {}
			private func makeService(dependency: Dependency) -> Service { Service() }
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

// 백틱 Factory 이름을 진단 문구에서 중복 인용하지 않는지 확인
@Test
func missingRegistrationPreservesEscapedFactoryName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func `makeService`(
				dependency: Dependency
			) -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func `makeService`(
				dependency: Dependency
			) -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "missingRegistration"),
				message: "`makeService`의 매개변수 `dependency`에 대응하는 등록이 없습니다.",
				line: 5,
				column: 3,
				highlights: ["dependency"],
				notes: [NoteSpec(message: "`makeService` Factory가 이 의존성을 요구합니다.", line: 3, column: 2)]
			)
		],
		macros: testMacros
	)
}
