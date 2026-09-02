//
//  ProvideMacro.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// marker와 본문 없는 Factory의 initializer 본문 생성
struct ProvideMacro: PeerMacro, BodyMacro {
	// `DependencyGraphMacro`가 읽을 marker만 유지
	static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let graph = context.lexicalContext.first?.as(ClassDeclSyntax.self),
			containsAttribute(named: "DependencyGraph", in: graph.attributes) else {
			context.diagnose(Diagnostic(node: node, message: CradleMacroDiagnostic.invalidProvidePlacement))
			return []
		}

		return []
	}

	// 본문 없는 Factory의 반환 타입 initializer 호출 생성
	static func expansion(
		of node: AttributeSyntax,
		providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
		in context: some MacroExpansionContext
	) throws -> [CodeBlockItemSyntax] {
		guard declaration.body == nil,
			let function = declaration.as(FunctionDeclSyntax.self),
			let body = generatedProviderBody(for: function) else {
			return []
		}
		return body
	}
}

// Factory 반환 타입과 매개변수로 initializer 표현식 생성
func generatedProviderBody(for function: FunctionDeclSyntax) -> [CodeBlockItemSyntax]? {
	guard let returnType = function.signature.returnClause?.type,
		!isDirectOptionalType(returnType),
		let parameters = providerParameterDescriptors(
			from: function.signature.parameterClause.parameters
		) else {
		return nil
	}
	let arguments = parameters.map { parameter in
		parameter.initializerArgument()
	}.joined(separator: ", ")
	return ["(\(raw: returnType.trimmedDescription)).init(\(raw: arguments))"]
}
