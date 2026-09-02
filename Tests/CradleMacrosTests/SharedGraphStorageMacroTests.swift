//
//  SharedGraphStorageMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// typed SharedStorage 선언이 저장 금지 표현 없이 생성되는지 확인
@Test
func sharedGraphStorageBuildsTypedLetDeclarations() throws {
	let providers = try sharedStorageProviders()
	let propertyNames = Dictionary(uniqueKeysWithValues: providers.map { provider in
		(provider.registrationIdentity, provider.propertyName)
	})
	let context = BasicMacroExpansionContext()
	let storage = SharedGraphStorage(
		graphName: .identifier("Graph"),
		providers: providers,
		sources: [],
		propertyNames: propertyNames,
		in: context
	)
	let source = storage.declarations().map(\.trimmedDescription).joined(separator: "\n")

	#expect(source.contains("private struct"))
	#expect(source.contains("let repository: any Repository"))
	#expect(source.contains("let client: Client"))
	#expect(source.contains("private static func"))
	#expect(source.contains("private let"))
	#expect(!source.contains("lazy"))
	#expect(!source.contains("Dictionary"))
	#expect(!source.contains("Any"))
	#expect(!source.contains("nil"))
	#expect(!source.contains("Optional"))
	#expect(!source.contains("?"))
}

// source를 직접 읽지 않는 shared Factory도 source 대입 뒤 저장소를 초기화하는지 확인
@Test
func sharedGraphStorageDefersSourceIndependentInitialization() throws {
	let providers = try sharedStorageProviders()
	let propertyNames = Dictionary(uniqueKeysWithValues: providers.map { provider in
		(provider.registrationIdentity, provider.propertyName)
	})
	let source = sharedStorageSource()
	let context = BasicMacroExpansionContext()
	let storage = SharedGraphStorage(
		graphName: .identifier("Graph"),
		providers: providers,
		sources: [source],
		propertyNames: propertyNames,
		in: context
	)
	let declarations = sourceGraphDeclarations(
		for: [source],
		accessLevel: .internal,
		storage: storage
	)
	let initializer = try #require(declarations.last?.trimmedDescription)
	let sourceAssignment = try #require(initializer.range(of: "self.appGraph = appGraph"))
	let storageAssignment = try #require(initializer.range(of: " = Graph."))
	let storageProperty = try #require(storage.declarations().last?.trimmedDescription)

	#expect(sourceAssignment.lowerBound < storageAssignment.lowerBound)
	#expect(storage.requiresSourceInitialization)
	#expect(!storageProperty.contains(" = "))
}

// shared Factory가 transient 등록을 요구하면 원본 타입 위치에서 거부하는지 확인
@Test
func sharedGraphStorageRejectsTransientDependency() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide(.shared)
			private func makeRoot(value: Value) -> Root { Root() }
			@Provide(.transient)
			private func makeValue() -> Value { Value() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeRoot(value: Value) -> Root { Root() }
			private func makeValue() -> Value { Value() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "invalidSharedProviderReference"),
				message: "shared 수명의 `@Provide` Factory는 `.transient` 등록을 매개변수로 받을 수 없습니다.",
				line: 4,
				column: 31,
				highlights: ["Value"]
			)
		],
		macros: testMacros
	)
}

// shared 저장소 생성용 등록 descriptor 구성
private func sharedStorageProviders() throws -> [ProviderDescriptor] {
	let repositoryType = TypeSyntax("any Repository")
	let clientType = TypeSyntax("Client")
	let repositoryFactory = try FunctionDeclSyntax(
		"private func makeRepository() -> any Repository { LiveRepository() }"
	)
	let clientFactory = try FunctionDeclSyntax(
		"private func makeClient(repository: any Repository) -> Client { Client() }"
	)
	let repository = ProviderDescriptor(
		attribute: AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Provide"))),
		factory: repositoryFactory,
		registeredType: RegisteredType(
			exposedType: repositoryType,
			identity: registeredTypeIdentity(for: repositoryType),
			propertyName: "repository"
		),
		parameters: [],
		lifetime: .shared
	)
	let client = ProviderDescriptor(
		attribute: AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Provide"))),
		factory: clientFactory,
		registeredType: RegisteredType(
			exposedType: clientType,
			identity: registeredTypeIdentity(for: clientType),
			propertyName: "client"
		),
		parameters: [
			ProviderParameterDescriptor(
				externalLabel: "repository",
				localName: "repository",
				localNameToken: .identifier("repository"),
				type: repositoryType,
				typeIdentity: registeredTypeIdentity(for: repositoryType)
			)
		],
		lifetime: .shared
	)
	return [repository, client]
}

// source 저장 프로퍼티와 생성 initializer 검증용 source descriptor 구성
private func sharedStorageSource() -> SourceGraphDescriptor {
	let type = TypeSyntax("AppGraph")
	return SourceGraphDescriptor(
		expression: ExprSyntax("AppGraph.self"),
		type: type,
		identity: registeredTypeIdentity(for: type),
		propertyName: "appGraph"
	)
}
