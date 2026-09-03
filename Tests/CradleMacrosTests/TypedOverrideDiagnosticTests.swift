//
//  TypedOverrideDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/3/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// `overrides` opt-in의 직접 Bool literal 제약 진단 확인
@Test
func typedOverrideGraphRejectsNonliteralConfiguration() {
	assertMacroExpansion(
		"""
		@DependencyGraph(overrides: enabled)
		final class Graph {}
		""",
		expandedSource: """
		final class Graph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidOverrideConfiguration"),
				message: "`overrides`는 직접 작성한 `true` 또는 `false`여야 합니다.",
				line: 1,
				column: 29,
				highlights: ["enabled"]
			)
		],
		macros: testMacros
	)
}

// override graph의 사용자 initializer 차단 진단 확인
@Test
func typedOverrideGraphRejectsUserInitializer() {
	assertMacroExpansion(
		"""
		@DependencyGraph(overrides: true)
		final class Graph {
			init() {}
		}
		""",
		expandedSource: """
		final class Graph {
			init() {}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "overrideUserInitializer"),
				message: "`overrides: true` graph는 initializer를 직접 선언할 수 없습니다.",
				line: 3,
				column: 2,
				highlights: ["init"]
			)
		],
		macros: testMacros
	)
}

// override graph의 초기값 없는 저장 프로퍼티 차단 진단 확인
@Test
func typedOverrideGraphRejectsUninitializedStoredProperty() {
	assertMacroExpansion(
		"""
		@DependencyGraph(overrides: true)
		final class Graph {
			private let token: Int
		}
		""",
		expandedSource: """
		final class Graph {
			private let token: Int
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "overrideUninitializedStoredProperty"),
				message: "`overrides: true` graph는 초기값 없는 인스턴스 저장 프로퍼티를 선언할 수 없습니다.",
				line: 3,
				column: 14,
				highlights: ["token"]
			)
		],
		macros: testMacros
	)
}

// generated override entry point 이름 충돌 진단 확인
@Test
func typedOverrideGraphRejectsOverrideNameCollision() {
	assertMacroExpansion(
		"""
		@DependencyGraph(overrides: true)
		final class Graph {
			static func `override`() {}
		}
		""",
		expandedSource: """
		final class Graph {
			static func `override`() {}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "overrideNameCollision"),
				message: "타입 지정 override가 생성할 `override` 이름이 기존 member와 충돌합니다.",
				line: 3,
				column: 2,
				highlights: ["static func `override`() {}"]
			)
		],
		macros: testMacros
	)
}

// generated builder 이름 충돌 진단 확인
@Test
func typedOverrideGraphRejectsBuilderNameCollision() {
	assertMacroExpansion(
		"""
		@DependencyGraph(overrides: true)
		final class Graph {
			struct OverrideBuilder {}
		}
		""",
		expandedSource: """
		final class Graph {
			struct OverrideBuilder {}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "overrideNameCollision"),
				message: "타입 지정 override가 생성할 `OverrideBuilder` 이름이 기존 member와 충돌합니다.",
				line: 3,
				column: 2,
				highlights: ["struct OverrideBuilder {}"]
			)
		],
		macros: testMacros
	)
}
