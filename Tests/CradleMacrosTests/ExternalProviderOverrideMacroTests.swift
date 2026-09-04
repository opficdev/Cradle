//
//  ExternalProviderOverrideMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/4/26.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import Testing
@testable import CradleMacros

// override 생성 코드가 전체 Factory 타입과 호출 시점 외부 입력을 보존하는지 확인
@Test
func externalProviderOverrideKeepsFactorySignature() throws {
	let file = Parser.parse(
		source: """
		@DependencyGraph(overrides: true)
		final class Graph {
			@Provide
			private func makeRepository() -> Repository { Repository() }
			@Provide(.transient)
			private func makeProfile(
				repository: Repository,
				@External id: Int
			) -> Profile { Profile() }
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
	#expect(source.contains("profile: DependencyOverride<(Repository, Int) -> Profile> = .original"))
	#expect(source.contains("internal func profile(id: Int) -> Profile"))
	#expect(source.contains("makeProfile(repository: repository, id: id)"))
	#expect(source.contains("factory(repository, id)"))
	#expect(!source.contains("External<Int>"))
}
