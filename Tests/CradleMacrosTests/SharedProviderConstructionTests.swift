//
//  SharedProviderConstructionTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftParser
import SwiftSyntax
import Testing
@testable import CradleMacros

// static helper가 명시 본문의 #function을 원래 Factory 이름으로 바꾸는지 확인
@Test
func sharedProviderConstructionPreservesOriginalFunctionIdentifier() throws {
	let factory = try sharedProviderFactory(
		"""
		@Provide(.shared)
		private func makeService() -> String { #function }
		"""
	)
	#expect(sharedHelperBody(for: factory) == "{ \"makeService()\"}")
}

// 중첩 함수 내부의 #function은 원래 지역 함수 의미를 보존하는지 확인
@Test
func sharedProviderConstructionPreservesNestedFunctionIdentifier() throws {
	let factory = try sharedProviderFactory(
		"""
		@Provide(.shared)
		private func makeService() -> String {
			func nested() -> String { #function }
			return #function + nested()
		}
		"""
	)
	let body = try #require(sharedHelperBody(for: factory))
	#expect(body.contains("func nested() -> String { #function }"))
	#expect(body.contains("return \"makeService()\"+ nested()"))
}

// 지역 선언의 #function 문맥을 바깥 Factory 이름으로 바꾸지 않는지 확인
@Test
func sharedProviderConstructionPreservesNestedDeclarationFunctionIdentifiers() throws {
	let factory = try sharedProviderFactory(
		"""
		@Provide(.shared)
		private func makeService() -> String {
			struct Local {
				init() { let initializer = #function }
				var value: String {
					get { #function }
					set { let setter = #function }
				}
				subscript(_ index: Int) -> String { #function }
				func method() -> String { #function }
			}
			let closure = { #function }
			return #function
		}
		"""
	)
	let body = try #require(sharedHelperBody(for: factory))

	#expect(body.contains("init() { let initializer = #function }"))
	#expect(body.contains("get { #function }"))
	#expect(body.contains("let setter = #function"))
	#expect(body.contains("subscript(_ index: Int) -> String { #function }"))
	#expect(body.contains("func method() -> String { #function }"))
	#expect(body.contains("let closure = { \"makeService()\"}"))
	#expect(body.contains("return \"makeService()\""))
}

// static helper가 bodyless Factory의 initializer 본문을 만드는지 확인
@Test
func sharedProviderConstructionBuildsBodylessInitializer() throws {
	let factory = try sharedProviderFactory(
		"""
		@Provide(.shared)
		private func makeFeature(client repository: Repository, _ logger: Logger) -> Feature
		"""
	)
	#expect(sharedHelperBody(for: factory) == "{\n(Feature).init(client: repository, logger)\n}")
}

// shared helper 생성용 Factory 구문 분석
private func sharedProviderFactory(_ source: String) throws -> FunctionDeclSyntax {
	let file = Parser.parse(source: source)
	return try #require(file.statements.first?.item.as(FunctionDeclSyntax.self))
}
