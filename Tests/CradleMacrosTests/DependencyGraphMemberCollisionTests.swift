//
//  DependencyGraphMemberCollisionTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 매개변수가 있는 instance method와 생성 접근자 공존 확인
@Test
func dependencyGraphAllowsParameterizedMemberName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			func service(value: Value) {}
			@Provide
			private func makeService() -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			func service(value: Value) {}
			private func makeService() -> Service { Service() }

		    internal func service() -> Service {
		        makeService()
		    }
		}
		""",
		macros: testMacros
	)
}

// 기존 instance property 충돌 거부 확인
@Test
func dependencyGraphRejectsExistingPropertyName() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			private var service: Service { Service() }
			@Provide
			private func makeService() -> Service { Service() }
		}
		""",
		expandedSource: """
		final class Graph {
			private var service: Service { Service() }
			private func makeService() -> Service { Service() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				message: "생성 접근자 이름이 기존 instance member와 충돌합니다.",
				line: 4,
				column: 2
			)
		],
		macros: testMacros
	)
}
