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

    internal var testUseCase: TestUseCase {
        buildTestUseCase()
    }

    internal var urlSession: URLSession {
        makeURLSession()
    }

    internal var httpClient: HTTPClient {
        createHTTPClient()
    }

    internal var id: ID {
        newID()
    }

    internal var moduleUseCase: Feature.ModuleUseCase {
        featureFactory()
    }
}
"""

// 숫자가 이어지는 initialism provider를 포함하는 원본 graph 문법
private let initialismGraphSource = """
@DependencyGraph
final class InitialismGraph {
	@Provide
	private func makeSHA256() -> SHA256 { SHA256() }
	@Provide
	private func makeHTTP2Client() -> HTTP2Client { HTTP2Client() }
	@Provide
	private func makeHTTPClient() -> HTTPClient { HTTPClient() }
	@Provide
	private func makeURLSession() -> URLSession { URLSession() }
	@Provide
	private func makeID() -> ID { ID() }
}
"""

// 숫자가 이어지는 initialism 접근자가 추가된 graph 문법
private let expandedInitialismGraphSource = """
final class InitialismGraph {
	private func makeSHA256() -> SHA256 { SHA256() }
	private func makeHTTP2Client() -> HTTP2Client { HTTP2Client() }
	private func makeHTTPClient() -> HTTPClient { HTTPClient() }
	private func makeURLSession() -> URLSession { URLSession() }
	private func makeID() -> ID { ID() }

    internal var sha256: SHA256 {
        makeSHA256()
    }

    internal var http2Client: HTTP2Client {
        makeHTTP2Client()
    }

    internal var httpClient: HTTPClient {
        makeHTTPClient()
    }

    internal var urlSession: URLSession {
        makeURLSession()
    }

    internal var id: ID {
        makeID()
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

// 숫자가 이어지는 initialism 접근자 이름 확인
@Test
func createsAccessorsForInitialismsWithDigits() {
	assertMacroExpansion(
		initialismGraphSource,
		expandedSource: expandedInitialismGraphSource,
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

			    \(accessorAccess) var service: Service {
			        makeService()
			    }
			}
			""",
			macros: testMacros
		)
	}
}

// 본문 없는 Factory와 graph member 확장의 결합 확인
@Test
func bodylessProviderGraphExpansionBuildsFactoryBodyAndAccessor() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func provideService() -> Service
		}
		""",
		expandedSource: """
		final class Graph {
			private func provideService() -> Service {
			    (Service).init()
			}

		    internal var service: Service {
		        provideService()
		    }
		}
		""",
		macros: testMacros
	)
}
