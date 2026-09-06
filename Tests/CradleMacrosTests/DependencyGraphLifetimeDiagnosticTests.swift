//
//  DependencyGraphLifetimeDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/6/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 비격리 class의 checked Sendable 준수 누락 진단 확인
@Test
func sharedGraphRequiresCheckedSendable() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		final class Graph {}
		""",
		expandedSource: """
		final class Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sharedGraphRequiresSendable"),
				message: "비격리 `final class`에서 `.shared`를 사용하려면 선언에 checked `Sendable` 준수를 직접 작성해야 합니다.",
				line: 1,
				column: 18,
				highlights: [".shared"]
			)
		],
		macros: testMacros
	)
}

// unchecked Sendable graph의 정적 접근점 거부 확인
@Test
func sharedGraphRejectsUncheckedSendable() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		final class Graph: @unchecked Sendable {}
		""",
		expandedSource: """
		final class Graph: @unchecked Sendable {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "uncheckedSharedGraph"),
				message: "비격리 `final class`의 `.shared`에는 `@unchecked Sendable`을 사용할 수 없습니다.",
				line: 1,
				column: 18,
				highlights: [".shared"]
			)
		],
		macros: testMacros
	)
}

// static shared member 충돌 진단 확인
@Test
func sharedGraphRejectsExistingStaticSharedMember() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		final class Graph: Sendable {
		static let shared = Graph()
		}
		""",
		expandedSource: """
		final class Graph: Sendable {
		static let shared = Graph()
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sharedGraphMemberCollision"),
				message: "생성할 `shared` static member가 기존 type member와 충돌합니다.",
				line: 1,
				column: 18,
				highlights: [".shared"]
			)
		],
		macros: testMacros
	)
}

// 중첩 type shared member 충돌 진단 확인
@Test
func sharedGraphRejectsExistingNestedSharedType() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		final class Graph: Sendable {
		enum shared {}
		}
		""",
		expandedSource: """
		final class Graph: Sendable {
		enum shared {}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sharedGraphMemberCollision"),
				message: "생성할 `shared` static member가 기존 type member와 충돌합니다.",
				line: 1,
				column: 18,
				highlights: [".shared"]
			)
		],
		macros: testMacros
	)
}

// escaped static shared member 충돌 진단 확인
@Test
func sharedGraphRejectsEscapedStaticSharedMember() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		final class Graph: Sendable {
		static let `shared` = Graph()
		}
		""",
		expandedSource: """
		final class Graph: Sendable {
		static let `shared` = Graph()
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sharedGraphMemberCollision"),
				message: "생성할 `shared` static member가 기존 type member와 충돌합니다.",
				line: 1,
				column: 18,
				highlights: [".shared"]
			)
		],
		macros: testMacros
	)
}

// 직접 case 이외 lifetime 표기 거부 확인
@Test
func dependencyGraphRejectsInvalidLifetimeExpression() {
	assertMacroExpansion(
		"""
		@DependencyGraph(DependencyGraphLifetime.shared)
		final class Graph: Sendable {}
		""",
		expandedSource: """
		final class Graph: Sendable {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidDependencyGraphLifetime"),
				message: "`@DependencyGraph`의 첫 위치 인자는 직접 작성한 `.instance` 또는 `.shared`여야 합니다.",
				line: 1,
				column: 18,
				highlights: ["DependencyGraphLifetime.shared"]
			)
		],
		macros: testMacros
	)
}
