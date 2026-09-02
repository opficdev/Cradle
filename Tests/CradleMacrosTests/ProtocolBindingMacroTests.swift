//
//  ProtocolBindingMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 프로토콜 반환 원문과 기존 접근자 명명 규칙 보존 확인
@Test
func protocolBindingPreservesReturnTypesAndAccessorNames() {
	// 반환 타입과 기대 접근자 이름
	let cases = [
		("any Repository", "repository"),
		("any Domain.Repository", "repository"),
		("any HTTPClient", "httpClient"),
		("any Module.`repository`", "`repository`"),
		("RepositoryAlias", "repositoryAlias")
	]

	for (type, name) in cases {
		assertMacroExpansion(
			"""
			@DependencyGraph
			final class Graph {
				@Provide
				private func makeValue() -> \(type) { LiveRepository() }
			}
			""",
			expandedSource: """
			final class Graph {
				private func makeValue() -> \(type) { LiveRepository() }

			    internal var \(name): \(type) {
			        makeValue()
			    }
			}
			""",
			macros: testMacros
		)
	}
}

// 프로토콜 매개변수의 지역 이름 연결과 외부 레이블 보존 확인
@Test
func protocolBindingPreservesParameterLabels() {
	// 매개변수 문법과 기대 호출 인자
	let cases = [
		("repository: any Repository", "repository: repository"),
		("client repository: any Repository", "client: repository"),
		("_ repository: any Repository", "repository"),
		("`default` repository: any Repository", "`default`: repository")
	]

	for (parameter, argument) in cases {
		assertMacroExpansion(
			"""
			@DependencyGraph
			final class Graph {
				@Provide
				private func makeConsumer(\(parameter)) -> Consumer { Consumer() }
				@Provide
				private func makeRepository() -> any Repository { LiveRepository() }
			}
			""",
			expandedSource: """
			final class Graph {
				private func makeConsumer(\(parameter)) -> Consumer { Consumer() }
				private func makeRepository() -> any Repository { LiveRepository() }

			    internal var consumer: Consumer {
			        makeConsumer(\(argument))
			    }

			    internal var repository: any Repository {
			        makeRepository()
			    }
			}
			""",
			macros: testMacros
		)
	}
}

// `any`와 바깥 괄호 표기가 달라도 같은 등록 타입으로 연결하는지 확인
@Test
func protocolBindingConnectsEquivalentExistentialTypes() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeConsumer(repository: any Repository) -> Consumer { Consumer() }
			@Provide
			private func makeRepository() -> (any Repository) { LiveRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(repository: any Repository) -> Consumer { Consumer() }
			private func makeRepository() -> (any Repository) { LiveRepository() }

		    internal var consumer: Consumer {
		        makeConsumer(repository: repository)
		    }

		    internal var repository: (any Repository) {
		        makeRepository()
		    }
		}
		""",
		macros: testMacros
	)
}

// 선언 순서와 다른 매개변수 순서로 프로토콜 의존성을 획득하는지 확인
@Test
func protocolBindingPreservesLabelsAndOrder() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeConsumer(client repository: any Repository, _ logger: any Logger) -> Consumer {
				Consumer(repository: repository, logger: logger)
			}
			@Provide
			private func makeLogger() -> any Logger { LiveLogger() }
			@Provide
			private func makeRepository() -> any Repository { LiveRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(client repository: any Repository, _ logger: any Logger) -> Consumer {
				Consumer(repository: repository, logger: logger)
			}
			private func makeLogger() -> any Logger { LiveLogger() }
			private func makeRepository() -> any Repository { LiveRepository() }

		    internal var consumer: Consumer {
		        makeConsumer(client: repository, logger)
		    }

		    internal var logger: any Logger {
		        makeLogger()
		    }

		    internal var repository: any Repository {
		        makeRepository()
		    }
		}
		""",
		macros: testMacros
	)
}

// 프로토콜 경로와 접근자의 백틱을 보존한 연결 확인
@Test
func protocolBindingPreservesEscapedNames() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeConsumer(client repository: any Module.repository) -> Consumer { Consumer() }
			@Provide
			private func makeRepository() -> any Module.`repository` { LiveRepository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeConsumer(client repository: any Module.repository) -> Consumer { Consumer() }
			private func makeRepository() -> any Module.`repository` { LiveRepository() }

		    internal var consumer: Consumer {
		        makeConsumer(client: `repository`)
		    }

		    internal var `repository`: any Module.`repository` {
		        makeRepository()
		    }
		}
		""",
		macros: testMacros
	)
}

// 프로토콜 반환 접근자에 그래프의 공개 접근 수준 적용 확인
@Test
func protocolBindingPreservesGraphAccessLevel() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		public final class Graph {
			@Provide
			private func makeRepository() -> any Repository { InternalRepository() }
		}
		""",
		expandedSource: """
		public final class Graph {
			private func makeRepository() -> any Repository { InternalRepository() }

		    public var repository: any Repository {
		        makeRepository()
		    }
		}
		""",
		macros: testMacros
	)
}
