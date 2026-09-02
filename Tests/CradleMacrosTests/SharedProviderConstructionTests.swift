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
