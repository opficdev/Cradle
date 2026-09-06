//
//  DependencyGraphLifetimeMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/6/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing

// checked Sendable graph의 정적 접근점 확장 확인
@Test
func sharedGraphCreatesStaticSharedMember() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		final class Graph: Sendable {}
		""",
		expandedSource: """
		final class Graph: Sendable {

		    internal static let shared: Graph = Graph()
		}
		""",
		macros: testMacros
	)
}

// actor graph의 정적 접근점 확장 확인
@Test
func sharedActorGraphCreatesStaticSharedMember() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		actor Graph {}
		""",
		expandedSource: """
		actor Graph {

		    internal static let shared: Graph = Graph()
		}
		""",
		macros: testMacros
	)
}

// 직접 instance lifetime이 기존 member 미생성을 유지하는지 확인
@Test
func instanceGraphDoesNotCreateStaticSharedMember() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.instance)
		final class Graph {}
		""",
		expandedSource: """
		final class Graph {}
		""",
		macros: testMacros
	)
}

// public graph의 정적 접근 수준 보존 확인
@Test
func publicSharedGraphPreservesAccessLevel() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		public final class Graph: Sendable {}
		""",
		expandedSource: """
		public final class Graph: Sendable {

		    public static let shared: Graph = Graph()
		}
		""",
		macros: testMacros
	)
}

// package graph의 정적 접근 수준 보존 확인
@Test
func packageSharedGraphPreservesAccessLevel() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared)
		package final class Graph: Sendable {}
		""",
		expandedSource: """
		package final class Graph: Sendable {

		    package static let shared: Graph = Graph()
		}
		""",
		macros: testMacros
	)
}

// source graph를 정규화한 순서로 정적 접근점에서 한 번씩 읽는지 확인
@Test
func sharedGraphBuildsSourcesFromStaticAccessPoints() {
	assertMacroExpansion(
		"""
		@DependencyGraph(.shared, sources: [SessionGraph.self, AppGraph.self])
		final class FeatureGraph: Sendable {}
		""",
		expandedSource: """
		final class FeatureGraph: Sendable {

		    private let appGraph: AppGraph

		    private let sessionGraph: SessionGraph

		    internal init(appGraph: AppGraph, sessionGraph: SessionGraph) {
		        self.appGraph = appGraph
		        self.sessionGraph = sessionGraph
		    }

		    internal static let shared: FeatureGraph = {
		        typealias __macro_local_18sharedappGraphTypefMu_ = AppGraph
		        let __macro_local_14sharedappGraphfMu_: __macro_local_18sharedappGraphTypefMu_ = __macro_local_18sharedappGraphTypefMu_.shared
		        typealias __macro_local_22sharedsessionGraphTypefMu_ = SessionGraph
		        let __macro_local_18sharedsessionGraphfMu_: __macro_local_22sharedsessionGraphTypefMu_ = __macro_local_22sharedsessionGraphTypefMu_.shared
		        return FeatureGraph(appGraph: __macro_local_14sharedappGraphfMu_, sessionGraph: __macro_local_18sharedsessionGraphfMu_)
		    }()
		}
		""",
		macros: testMacros
	)
}
