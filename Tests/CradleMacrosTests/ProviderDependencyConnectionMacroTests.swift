//
//  ProviderDependencyConnectionMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 지역 이름 연결과 외부 인자 레이블 보존 확인
@Test
func providerDependencyConnectionPreservesParameterLabels() {
	// 매개변수 선언과 기대 factory 인자
	let fixtures = [
		("urlSession: URLSession", "urlSession: urlSession"),
		("session urlSession: URLSession", "session: urlSession"),
		("_ urlSession: URLSession", "urlSession"),
		("session `urlSession`: URLSession", "session: urlSession"),
		("`default` urlSession: URLSession", "`default`: urlSession")
	]

	for (parameter, argument) in fixtures {
		assertMacroExpansion(
			"""
			@DependencyGraph
			final class Graph {
				@Provide
				private func makeHTTPClient(\(parameter)) -> HTTPClient { HTTPClient() }
				@Provide
				private func makeURLSession() -> URLSession { URLSession() }
			}
			""",
			expandedSource: """
			final class Graph {
				private func makeHTTPClient(\(parameter)) -> HTTPClient { HTTPClient() }
				private func makeURLSession() -> URLSession { URLSession() }

			    internal var httpClient: HTTPClient {
			        makeHTTPClient(\(argument))
			    }

			    internal var urlSession: URLSession {
			        makeURLSession()
			    }
			}
			""",
			macros: testMacros
		)
	}
}

// provider 선언 순서와 다른 매개변수 순서의 생성 접근자 호출 확인
@Test
func providerDependencyConnectionPreservesParameterOrder() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class FeatureGraph {
			@Provide
			private func makeFeature(session urlSession: URLSession, _ logger: Logger) -> Feature {
				Feature(urlSession: urlSession, logger: logger)
			}
			@Provide
			private func makeLogger() -> Logger { Logger() }
			@Provide
			private func makeURLSession() -> URLSession { URLSession() }
		}
		""",
		expandedSource: """
		final class FeatureGraph {
			private func makeFeature(session urlSession: URLSession, _ logger: Logger) -> Feature {
				Feature(urlSession: urlSession, logger: logger)
			}
			private func makeLogger() -> Logger { Logger() }
			private func makeURLSession() -> URLSession { URLSession() }

		    internal var feature: Feature {
		        makeFeature(session: urlSession, logger)
		    }

		    internal var logger: Logger {
		        makeLogger()
		    }

		    internal var urlSession: URLSession {
		        makeURLSession()
		    }
		}
		""",
		macros: testMacros
	)
}
