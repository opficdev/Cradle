//
//  ExternalProviderMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// graph 의존성과 외부 입력을 원본 순서대로 전달하는 생성 메서드 확인
@Test
func externalProviderMethodPreservesMixedParameterOrder() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeProfile(
				@External _ id: UserID,
				repository: Repository,
				@External locale code: LocaleID,
				logger: Logger
			) -> Profile {
				Profile(repository: repository, id: id, locale: code)
			}
			@Provide(.transient)
			private func makeRepository() -> Repository { Repository() }
			@Provide(.transient)
			private func makeLogger() -> Logger { Logger() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeProfile(
				@External _ id: UserID,
				repository: Repository,
				@External locale code: LocaleID,
				logger: Logger
			) -> Profile {
				Profile(repository: repository, id: id, locale: code)
			}
			private func makeRepository() -> Repository { Repository() }
			private func makeLogger() -> Logger { Logger() }

		    internal func profile(_ id: UserID, locale code: LocaleID) -> Profile {
		        self.makeProfile(id, repository: self.repository, locale: code, logger: self.logger)
		    }

		    internal var repository: Repository {
		        makeRepository()
		    }

		    internal var logger: Logger {
		        makeLogger()
		    }
		}
		""",
		macros: testMacros
	)
}

// 본문 없는 Factory의 외부 입력과 graph 의존성 전달 확인
@Test
func externalProviderMethodSupportsBodylessFactory() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeProfile(repository: Repository, @External id: UserID) -> Profile
			@Provide(.transient)
			private func makeRepository() -> Repository { Repository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeProfile(repository: Repository, @External id: UserID) -> Profile {
			    (Profile).init(repository: repository, id: id)
			}
			private func makeRepository() -> Repository { Repository() }

		    internal func profile(id: UserID) -> Profile {
		        self.makeProfile(repository: self.repository, id: id)
		    }

		    internal var repository: Repository {
		        makeRepository()
		    }
		}
		""",
		macros: testMacros
	)
}

// 외부 입력 지역 이름과 같은 Factory와 graph 접근자 참조 한정 확인
@Test
func externalProviderMethodQualifiesShadowedGraphMembers() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.transient)
			private func makeProfile(
				service: Repository,
				@External id repository: Int,
				@External makeProfile: String
			) -> Profile { Profile() }
			@Provide(.transient)
			private func makeRepository() -> Repository { Repository() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeProfile(
				service: Repository,
				@External id repository: Int,
				@External makeProfile: String
			) -> Profile { Profile() }
			private func makeRepository() -> Repository { Repository() }

		    internal func profile(id repository: Int, makeProfile: String) -> Profile {
		        self.makeProfile(service: self.repository, id: repository, makeProfile: makeProfile)
		    }

		    internal var repository: Repository {
		        makeRepository()
		    }
		}
		""",
		macros: testMacros
	)
}
