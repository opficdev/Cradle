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

			    internal func \(name)() -> \(type) {
			        makeValue()
			    }
			}
			""",
			macros: testMacros
		)
	}
}
