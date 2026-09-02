//
//  SourceGraphMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// 두 source graph를 역순으로 선언한 조합 graph 문법
private let unorderedSourceGraph = """
@DependencyGraph(sources: [
	SessionGraph.self,
	AppGraph.self,
])
final class FeatureGraph {
	@Provide
	private func makeFeature() -> Feature {
		Feature(
			repository: appGraph.repository,
			session: sessionGraph.session
		)
	}
}
"""

// source type identity 순서로 정렬한 조합 graph 확장 문법
private let expandedSourceGraph = """
final class FeatureGraph {
	private func makeFeature() -> Feature {
		Feature(
			repository: appGraph.repository,
			session: sessionGraph.session
		)
	}

    private let appGraph: AppGraph

    private let sessionGraph: SessionGraph

    internal init(appGraph: AppGraph, sessionGraph: SessionGraph) {
        self.appGraph = appGraph
        self.sessionGraph = sessionGraph
    }

    internal var feature: Feature {
        makeFeature()
    }
}
"""

// source 배열 순서와 무관한 저장 프로퍼티·initializer 생성 확인
@Test
func sourceGraphMacroCreatesCanonicalStorageAndInitializer() {
	assertMacroExpansion(
		unorderedSourceGraph,
		expandedSource: expandedSourceGraph,
		macros: testMacros
	)
}

// protocol-only 조합 graph에서 `super.init()`을 생성하지 않는지 확인
@Test
func sourceGraphMacroPreservesProtocolConformanceWithoutSuperCall() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph: FeatureGraphProtocol {}
		""",
		expandedSource: """
		final class FeatureGraph: FeatureGraphProtocol {

		    private let appGraph: AppGraph

		    internal init(appGraph: AppGraph) {
		        self.appGraph = appGraph
		    }
		}
		""",
		macros: testMacros
	)
}

// superclass 구문도 보존하고 `super.init()`을 생성하지 않는지 확인
@Test
func sourceGraphMacroPreservesSuperclassClauseWithoutSuperCall() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph: BaseGraph {}
		""",
		expandedSource: """
		final class FeatureGraph: BaseGraph {

		    private let appGraph: AppGraph

		    internal init(appGraph: AppGraph) {
		        self.appGraph = appGraph
		    }
		}
		""",
		macros: testMacros
	)
}

// source 없는 subclass에 initializer를 추가하지 않는지 확인
@Test
func sourceGraphMacroDoesNotGenerateInitializerForNoSourceSubclass() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class FeatureGraph: BaseGraph {}
		""",
		expandedSource: """
		final class FeatureGraph: BaseGraph {}
		""",
		macros: testMacros
	)
}
