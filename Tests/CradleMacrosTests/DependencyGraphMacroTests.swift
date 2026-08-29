//
//  DependencyGraphMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 구체 반환 타입 provider를 포함하는 원본 graph 문법
private let appGraphSource = """
@DependencyGraph
final class AppGraph {
	@Provide
	private func buildTestUseCase() -> TestUseCase {
		TestUseCase()
	}
	@Provide
	private func makeURLSession() -> URLSession {
		URLSession()
	}
	@Provide
	private func createHTTPClient() -> HTTPClient {
		HTTPClient()
	}
	@Provide
	private func newID() -> ID {
		ID()
	}
	@Provide
	private func featureFactory() -> Feature.ModuleUseCase {
		Feature.ModuleUseCase()
	}
}
"""

// 반환 타입 기반 접근자가 추가된 graph 문법
private let expandedAppGraphSource = """
final class AppGraph {
	private func buildTestUseCase() -> TestUseCase {
		TestUseCase()
	}
	private func makeURLSession() -> URLSession {
		URLSession()
	}
	private func createHTTPClient() -> HTTPClient {
		HTTPClient()
	}
	private func newID() -> ID {
		ID()
	}
	private func featureFactory() -> Feature.ModuleUseCase {
		Feature.ModuleUseCase()
	}

    internal func testUseCase() -> TestUseCase {
        buildTestUseCase()
    }

    internal func urlSession() -> URLSession {
        makeURLSession()
    }

    internal func httpClient() -> HTTPClient {
        createHTTPClient()
    }

    internal func id() -> ID {
        newID()
    }

    internal func moduleUseCase() -> Feature.ModuleUseCase {
        featureFactory()
    }
}
"""

// provider 없는 graph의 member 미추가 확인
@Test
func emptyGraphDoesNotAddMember() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class EmptyGraph {}
		""",
		expandedSource: """
		final class EmptyGraph {}
		""",
		macros: testMacros
	)
}

// 구체 반환 타입 기반 접근자 이름과 직접 factory 호출 확인
@Test
func createsAccessorsFromConcreteReturnTypes() {
	assertMacroExpansion(
		appGraphSource,
		expandedSource: expandedAppGraphSource,
		macros: testMacros
	)
}

// graph 접근 수준을 따르는 생성 접근자 확인
@Test
func accessorsUseTheGraphAccessLevel() {
	// graph와 생성 접근자의 기대 접근 수준
	let fixtures = [
		("private", "private"),
		("fileprivate", "fileprivate"),
		("", "internal"),
		("internal", "internal"),
		("package", "package"),
		("public", "public")
	]

	for (graphAccess, accessorAccess) in fixtures {
		// Macro 입력에 사용할 graph 접근 수정자
		let graphModifier = graphAccess.isEmpty ? "" : "\(graphAccess) "

		assertMacroExpansion(
			"""
			@DependencyGraph
			\(graphModifier)final class Graph {
				@Provide
				private func makeService() -> Service { Service() }
			}
			""",
			expandedSource: """
			\(graphModifier)final class Graph {
				private func makeService() -> Service { Service() }

			    \(accessorAccess) func service() -> Service {
			        makeService()
			    }
			}
			""",
			macros: testMacros
		)
	}
}
