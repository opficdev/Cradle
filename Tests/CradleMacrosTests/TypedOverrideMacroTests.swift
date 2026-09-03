//
//  TypedOverrideMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/3/26.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import Testing
@testable import CradleMacros

// public graph의 override entry point와 builder 접근 수준 확인
@Test
func publicDependencyGraphCreatesPublicOverrideBuilder() throws {
	let file = Parser.parse(
		source: """
		@DependencyGraph(overrides: true)
		public final class Graph {
			@Provide
			private func makeService() -> Service { Service() }
		}
		"""
	)
	let graph = try #require(file.statements.first?.item.as(ClassDeclSyntax.self))
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
	#expect(source.contains("public struct OverrideBuilder"))
	#expect(source.contains("public func build() -> Graph"))
	#expect(source.contains("public static func `override`"))
}
