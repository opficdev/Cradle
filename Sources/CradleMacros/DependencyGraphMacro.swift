//
//  DependencyGraphMacro.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// `@Provide` factory를 호출하는 기본 `internal` 생성 접근자 추가
struct DependencyGraphMacro: MemberMacro {
	// graph 본체의 유효한 factory별 transient 접근자 생성
	static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let graph = declaration.as(ClassDeclSyntax.self) else {
			return []
		}

		return graph.memberBlock.members.compactMap { member in
			guard let function = member.decl.as(FunctionDeclSyntax.self),
				containsAttribute(named: "Provide", in: function.attributes),
				let provider = providerDescriptor(from: function) else {
				return nil
			}

			return DeclSyntax(
				"""
				internal func \(raw: provider.accessorName)() -> \(raw: provider.returnType.trimmedDescription) {
				    \(raw: provider.factoryName)()
				}
				"""
			)
		}
	}

	// G1의 정상 provider 문법을 접근자 생성 정보로 변환
	private static func providerDescriptor(from function: FunctionDeclSyntax) -> ProviderDescriptor? {
		guard function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }),
			!function.modifiers.contains(where: {
				$0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
			}),
			function.signature.parameterClause.parameters.isEmpty,
			function.genericParameterClause == nil,
			function.signature.effectSpecifiers == nil,
			let returnClause = function.signature.returnClause,
			function.body != nil,
			let accessorName = accessorName(for: returnClause.type) else {
			return nil
		}

		return ProviderDescriptor(
			factoryName: function.name.text,
			returnType: returnClause.type,
			accessorName: accessorName
		)
	}
}
