//
//  ProvideBodyMacroTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import Testing
@testable import CradleMacros

// 본문 없는 Factory의 반환 타입 initializer 생성 확인
@Test
func bodylessProviderBodyMacroBuildsInitializer() throws {
	let fixture = try providerFunction(
		"""
		@Provide(.transient)
		private func todoSnapshot(
			repository: TodoRepository
		) -> TodoSnapshot
		"""
	)
	let body = try ProvideMacro.expansion(
		of: fixture.attribute,
		providingBodyFor: fixture.function,
		in: fixture.context
	)

	#expect(body.map(\.trimmedDescription).joined(separator: "\n") == "(TodoSnapshot).init(repository: repository)")
	#expect(fixture.context.diagnostics.isEmpty)
}

// 외부 레이블과 지역 이름의 구분 유지 확인
@Test
func bodylessProviderBodyMacroPreservesLabelsAndOrder() throws {
	let fixture = try providerFunction(
		"""
		@Provide(.transient)
		private func feature(
			client repository: Repository,
			_ logger: Logger
		) -> Feature
		"""
	)
	let body = try ProvideMacro.expansion(
		of: fixture.attribute,
		providingBodyFor: fixture.function,
		in: fixture.context
	)

	#expect(body.map(\.trimmedDescription).joined(separator: "\n") == "(Feature).init(client: repository, logger)")
	#expect(fixture.context.diagnostics.isEmpty)
}

// 명시 본문을 BodyMacro가 교체하지 않는지 확인
@Test
func bodylessProviderBodyMacroPreservesExplicitBody() throws {
	let fixture = try providerFunction(
		"""
		@Provide(.transient)
		private func service() -> Service { customService() }
		"""
	)
	let body = try ProvideMacro.expansion(
		of: fixture.attribute,
		providingBodyFor: fixture.function,
		in: fixture.context
	)

	#expect(body.isEmpty)
	#expect(fixture.context.diagnostics.isEmpty)
}

// BodyMacro 직접 호출에 필요한 원본 구문과 context
private struct ProviderFunctionFixture {
	let attribute: AttributeSyntax
	let function: FunctionDeclSyntax
	let context: BasicMacroExpansionContext
}

// BodyMacro 적용 대상 Factory 생성
private func providerFunction(_ source: String) throws -> ProviderFunctionFixture {
	let file = Parser.parse(source: source)
	let function = try #require(file.statements.first?.item.as(FunctionDeclSyntax.self))
	let attribute = try #require(function.attributes.first?.as(AttributeSyntax.self))
	let context = BasicMacroExpansionContext(sourceFiles: [
		file: .init(moduleName: "Fixture", fullFilePath: "/Fixture.swift")
	])
	return ProviderFunctionFixture(attribute: attribute, function: function, context: context)
}
