//
//  EscapedProviderDependencyConnectionMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 백틱과 외부 레이블 표기가 달라도 같은 생성 접근자로 연결되는지 확인
@Test
func providerDependencyConnectionPreservesEscapedAccessorNames() {
	// 반환 타입, 매개변수 선언, 기존 접근자 이름과 기대 호출 인자
	let fixtures = [
		("dependency", "dependency: dependency", "dependency", "dependency: dependency()"),
		("`dependency`", "dependency: dependency", "`dependency`", "dependency: `dependency`()"),
		("`dependency`", "client `dependency`: dependency", "`dependency`", "client: `dependency`()"),
		("Module.`dependency`", "_ dependency: Module.dependency", "`dependency`", "`dependency`()"),
		("`default`", "default: `default`", "`default`", "default: `default`()"),
		("`default`", "`default`: `default`", "`default`", "`default`: `default`()"),
		("`Dependency`", "value Dependency: Dependency", "`Dependency`", "value: `Dependency`()")
	]

	for (returnType, parameter, accessor, argument) in fixtures {
		assertMacroExpansion(
			"""
			@DependencyGraph
			final class Graph {
				@Provide
				private func makeService(\(parameter)) -> Service { .init() }
				@Provide
				private func makeDependency() -> \(returnType) { .init() }
			}
			""",
			expandedSource: """
			final class Graph {
				private func makeService(\(parameter)) -> Service { .init() }
				private func makeDependency() -> \(returnType) { .init() }

			    internal func service() -> Service {
			        makeService(\(argument))
			    }

			    internal func \(accessor)() -> \(returnType) {
			        makeDependency()
			    }
			}
			""",
			macros: testMacros
		)
	}
}

// 백틱 유무만 다른 중복 접근자를 이름 조회표 생성 전에 거부하는지 확인
@Test
func providerDependencyConnectionRejectsEscapedDuplicateAccessors() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeFirst() -> dependency { .init() }
			@Provide
			private func makeSecond() -> `dependency` { .init() }
			@Provide
			private func makeService(dependency: dependency) -> Service { .init() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeFirst() -> dependency { .init() }
			private func makeSecond() -> `dependency` { .init() }
			private func makeService(dependency: dependency) -> Service { .init() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "반환 타입이 만드는 생성 접근자 이름이 중복됩니다.",
				line: 3,
				column: 2
			),
			DiagnosticSpec(
				message: "반환 타입이 만드는 생성 접근자 이름이 중복됩니다.",
				line: 5,
				column: 2
			)
		],
		macros: testMacros
	)
}
