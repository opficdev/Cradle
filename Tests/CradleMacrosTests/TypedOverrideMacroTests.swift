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

// 자동 초기화 저장 프로퍼티가 override 진단을 만들지 않는지 확인
@Test
func typedOverrideGraphAllowsAutomaticStoredPropertyInitialization() throws {
	let file = Parser.parse(
		source: """
		@DependencyGraph(overrides: true)
		final class Graph {
			weak var delegate: (any Delegate)?
			var cache: Cache?
			@Defaulted var count: Int
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
	#expect(source.contains("internal struct OverrideBuilder"))
}

// checked Sendable shared graph의 override Factory 동시성 경계 확인
@Test
func sharedGraphOverrideRequiresSendableFactory() throws {
	let source = try typedOverrideExpansionSource(
		"""
		@DependencyGraph(.shared, overrides: true)
		final class Graph: Sendable {
			@Provide
			private func makeService() -> Service { Service() }
		}
		"""
	)

	#expect(source.contains("@Sendable () -> Service"))
	#expect(source.contains("internal struct OverrideBuilder: Sendable"))
	#expect(source.contains("internal static let shared: Graph = Graph()"))
}

// 일반 instance graph의 override Factory capture 허용 범위 보존 확인
@Test
func instanceGraphOverrideDoesNotRequireSendableFactory() throws {
	let source = try typedOverrideExpansionSource(
		"""
		@DependencyGraph(overrides: true)
		final class Graph: Sendable {
			@Provide
			private func makeService() -> Service { Service() }
		}
		"""
	)

	#expect(!source.contains("@Sendable () -> Service"))
	#expect(!source.contains("static let shared"))
}

// override graph 확장 결과의 선언 문자열 반환
private func typedOverrideExpansionSource(_ source: String) throws -> String {
	let file = Parser.parse(source: source)
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

	#expect(context.diagnostics.isEmpty)
	return declarations.map(\.trimmedDescription).joined(separator: "\n")
}
