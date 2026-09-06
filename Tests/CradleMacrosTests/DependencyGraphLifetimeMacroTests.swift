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
