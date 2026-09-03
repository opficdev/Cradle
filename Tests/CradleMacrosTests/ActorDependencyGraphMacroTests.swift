//
//  ActorDependencyGraphMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/3/26.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// actor graph의 transient 생성 접근자 확장 확인
@Test
func actorDependencyGraphCreatesIsolatedTransientAccessor() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		actor Graph {
			@Provide(.transient)
			private func makeService() -> Service { Service() }
		}
		""",
		expandedSource: """
		actor Graph {
			private func makeService() -> Service { Service() }

		    internal var service: Service {
		        makeService()
		    }
		}
		""",
		macros: testMacros
	)
}

// actor graph의 shared 생성 접근자와 저장소 확장 확인
@Test
func actorDependencyGraphCreatesIsolatedSharedAccessor() throws {
	let file = Parser.parse(
		source: """
		@DependencyGraph
		actor Graph {
			@Provide(.shared)
			private func makeService() -> Service { Service() }
		}
		"""
	)
	let graph = try #require(file.statements.first?.item.as(ActorDeclSyntax.self))
	let attribute = try #require(graph.attributes.first?.as(AttributeSyntax.self))
	let context = BasicMacroExpansionContext(sourceFiles: [
		file: .init(moduleName: "Fixture", fullFilePath: "/Fixture.swift")
	])
	let declarations = try DependencyGraphMacro.expansion(
		of: attribute,
		providingMembersOf: graph,
		conformingTo: [],
		in: context
	)
	let source = declarations.map(\.trimmedDescription).joined(separator: "\n")

	#expect(context.diagnostics.isEmpty)
	#expect(source.contains("private struct"))
	#expect(source.contains("let service: Service"))
	#expect(source.contains("private static func"))
	#expect(source.contains("private let"))
	#expect(source.contains("internal var service: Service"))
	#expect(!source.contains("nonisolated"))
}

// actor graph의 교체 Factory와 builder Sendable 선언 확인
@Test
func actorDependencyGraphCreatesSendableOverrideBuilder() throws {
	let file = Parser.parse(
		source: """
		@DependencyGraph(overrides: true)
		actor Graph {
			@Provide
			private func makeService() -> Service { Service() }
		}
		"""
	)
	let graph = try #require(file.statements.first?.item.as(ActorDeclSyntax.self))
	let attribute = try #require(graph.attributes.first?.as(AttributeSyntax.self))
	let context = BasicMacroExpansionContext(sourceFiles: [
		file: .init(moduleName: "Fixture", fullFilePath: "/Fixture.swift")
	])
	let declarations = try DependencyGraphMacro.expansion(
		of: attribute,
		providingMembersOf: graph,
		conformingTo: [],
		in: context
	)
	let source = declarations.map(\.trimmedDescription).joined(separator: "\n")

	#expect(context.diagnostics.isEmpty)
	#expect(source.contains("@Sendable () -> Service"))
	#expect(source.contains("struct OverrideBuilder: Sendable"))
	#expect(source.contains("enum __macro_local_"))
	#expect(source.contains(": Sendable"))
}

// MainActor graph의 override 진입점과 builder 격리 선언 확인
@Test
func mainActorDependencyGraphCreatesIsolatedOverrideBuilder() throws {
	let file = Parser.parse(
		source: """
		@_Concurrency.`MainActor`
		@DependencyGraph(overrides: true)
		final class Graph {
			@Provide
			private func makeService() -> Service { Service() }
		}
		"""
	)
	let graph = try #require(file.statements.first?.item.as(ClassDeclSyntax.self))
	let attribute = try #require(graph.attributes.last?.as(AttributeSyntax.self))
	let context = BasicMacroExpansionContext(sourceFiles: [
		file: .init(moduleName: "Fixture", fullFilePath: "/Fixture.swift")
	])
	let declarations = try DependencyGraphMacro.expansion(
		of: attribute,
		providingMembersOf: graph,
		conformingTo: [],
		in: context
	)
	let source = declarations.map(\.trimmedDescription).joined(separator: "\n")

	#expect(context.diagnostics.isEmpty)
	#expect(source.contains("@MainActor\ninternal struct OverrideBuilder"))
	#expect(source.contains("@MainActor\ninternal static func `override`"))
}
