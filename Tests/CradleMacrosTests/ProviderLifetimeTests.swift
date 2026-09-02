//
//  ProviderLifetimeTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import Testing
@testable import CradleMacros

// 인자 생략과 빈 괄호의 기본 shared 수명 확인
@Test(arguments: ["@Provide", "@Provide()", "@Provide(/* 기본값 */)"])
func providerLifetimePreservesDefault(source: String) throws {
	let (attribute, context) = try lifetimeAttribute(source)
	#expect(providerLifetime(from: attribute, in: context) == .shared)
	#expect(context.diagnostics.isEmpty)
}

// 주석과 백틱을 포함한 직접 shared case 표기 허용 확인
@Test(arguments: ["@Provide(.shared)", "@Provide(/* 수명 */ .shared)", "@Provide(.`shared`)"])
func providerLifetimeAcceptsShared(source: String) throws {
	let (attribute, context) = try lifetimeAttribute(source)
	#expect(providerLifetime(from: attribute, in: context) == .shared)
	#expect(context.diagnostics.isEmpty)
}

// 주석과 백틱을 포함한 직접 transient case 표기 허용 확인
@Test(arguments: ["@Provide(.transient)", "@Provide(/* 수명 */ .transient)", "@Provide(.`transient`)"])
func providerLifetimeAcceptsTransient(source: String) throws {
	let (attribute, context) = try lifetimeAttribute(source)
	#expect(providerLifetime(from: attribute, in: context) == .transient)
	#expect(context.diagnostics.isEmpty)
}

// 지원하지 않는 수명 인자를 원본 인자 위치의 오류로 분류 확인
@Test(arguments: [
	"DependencyLifetime.shared", "DependencyLifetime.transient", "lifetime", "lifetime()",
	".shared()", "lifetime: .shared", ".shared, .shared", "(.shared)", "42", ".shared(value:)"
])
func providerLifetimeRejectsUnsupportedArguments(argument: String) throws {
	let (attribute, context) = try lifetimeAttribute("@Provide(\(argument))")
	#expect(providerLifetime(from: attribute, in: context) == nil)
	#expect(context.diagnostics.count == 1)

	let diagnostic = try #require(context.diagnostics.first)
	#expect(diagnostic.diagnosticID == .init(domain: "Cradle", id: "invalidProviderLifetime"))
	#expect(diagnostic.diagMessage.severity == .error)
	#expect(diagnostic.message == "`@Provide` 인자는 생략하거나 `.shared` 또는 `.transient`로 직접 지정해야 합니다.")
	#expect(diagnostic.node.trimmedDescription == argument)
	#expect(diagnostic.notes.isEmpty)
	#expect(diagnostic.fixIts.isEmpty)
}

// 독립된 원본 파일과 위치 정보를 가진 등록 attribute 생성
private func lifetimeAttribute(_ source: String) throws -> (AttributeSyntax, BasicMacroExpansionContext) {
	let file = Parser.parse(source: "\(source)\nfunc factory() {}")
	let function = try #require(file.statements.first?.item.as(FunctionDeclSyntax.self))
	let attribute = try #require(function.attributes.first?.as(AttributeSyntax.self))
	let context = BasicMacroExpansionContext(sourceFiles: [
		file: .init(moduleName: "Fixture", fullFilePath: "/Fixture.swift")
	])
	return (attribute, context)
}
