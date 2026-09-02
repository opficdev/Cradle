//
//  SourceGraphDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 비어 있는 source 배열 진단 확인
@Test
func sourceGraphMacroRejectsEmptySources() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [])
		final class FeatureGraph {}
		""",
		expandedSource: """
		final class FeatureGraph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "emptySources"),
				message: "`sources`에는 하나 이상의 `GraphType.self`이 필요합니다.",
				line: 1,
				column: 27,
				highlights: ["[]"]
			)
		],
		macros: testMacros
	)
}

// `.self`이 아닌 source 원소 진단 확인
@Test
func sourceGraphMacroRejectsNonTypeSource() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [makeAppGraph()])
		final class FeatureGraph {}
		""",
		expandedSource: """
		final class FeatureGraph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidSource"),
				message: "`sources` 원소는 `GraphType.self` 형식이어야 합니다.",
				line: 1,
				column: 28,
				highlights: ["makeAppGraph()"]
			)
		],
		macros: testMacros
	)
}

// 같은 source type 중복 진단과 첫 선언 보조 설명 확인
@Test
func sourceGraphMacroRejectsDuplicateSource() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self, AppGraph.self])
		final class FeatureGraph {}
		""",
		expandedSource: """
		final class FeatureGraph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "duplicateSource"),
				message: "`AppGraph` source graph가 중복되었습니다.",
				line: 1,
				column: 43,
				highlights: ["AppGraph.self"],
				notes: [
					NoteSpec(
						message: "`AppGraph` source graph가 여기에서 선언되었습니다.",
						line: 1,
						column: 28
					)
				]
			)
		],
		macros: testMacros
	)
}

// 마지막 type 이름이 같은 서로 다른 source의 저장 이름 충돌 진단 확인
@Test
func sourceGraphMacroRejectsSourceStorageNameCollision() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [First.AppGraph.self, Second.AppGraph.self])
		final class FeatureGraph {}
		""",
		expandedSource: """
		final class FeatureGraph {}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sourceNameCollision"),
				message: "`appGraph` source 저장 프로퍼티 이름이 충돌합니다.",
				line: 1,
				column: 49,
				highlights: ["Second.AppGraph.self"],
				notes: [
					NoteSpec(
						message: "`First.AppGraph` source graph가 여기에서 선언되었습니다.",
						line: 1,
						column: 28
					)
				]
			)
		],
		macros: testMacros
	)
}

// source 저장 이름과 사용자 instance member 충돌 진단 확인
@Test
func sourceGraphMacroRejectsExistingSourceStorageName() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph {
			private let appGraph = ExistingGraph()
		}
		""",
		expandedSource: """
		final class FeatureGraph {
			private let appGraph = ExistingGraph()
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sourceNameCollision"),
				message: "`appGraph` source 저장 프로퍼티 이름이 충돌합니다.",
				line: 1,
				column: 28,
				highlights: ["AppGraph.self"]
			)
		],
		macros: testMacros
	)
}

// source graph의 초기값 없는 저장 프로퍼티 충돌 진단 확인
@Test
func sourceGraphMacroRejectsUninitializedStoredProperty() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph {
			private let token: Int
		}
		""",
		expandedSource: """
		final class FeatureGraph {
			private let token: Int
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sourceUninitializedStoredProperty"),
				message: "`sources` graph는 초기값 없는 인스턴스 저장 프로퍼티를 선언할 수 없습니다.",
				line: 3,
				column: 14,
				highlights: ["token"]
			)
		],
		macros: testMacros
	)
}

// source graph와 사용자 initializer 충돌 진단 확인
@Test
func sourceGraphMacroRejectsUserInitializer() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph {
			init() {}
		}
		""",
		expandedSource: """
		final class FeatureGraph {
			init() {}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sourceUserInitializer"),
				message: "`sources` graph는 initializer를 직접 선언할 수 없습니다.",
				line: 3,
				column: 2,
				highlights: ["init"]
			)
		],
		macros: testMacros
	)
}
