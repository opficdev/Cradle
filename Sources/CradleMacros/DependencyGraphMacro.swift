//
//  DependencyGraphMacro.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftDiagnostics
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
		guard let graph = declaration.as(ClassDeclSyntax.self),
			isFinal(graph),
			graph.genericParameterClause == nil,
			graph.genericWhereClause == nil else {
			context.diagnose(Diagnostic(node: node, message: CradleMacroDiagnostic.invalidGraph))
			return []
		}

		// graph 본체에서 읽은 provider 검증 결과
		let providerResult = providers(in: graph, context: context)
		// 생성 접근자에 적용할 graph 접근 수준
		let graphAccess = accessLevel(of: graph)
		// 기존 instance member 이름
		let memberNames = instanceMemberNames(in: graph)
		// 생성 접근자 이름 충돌 검증 결과
		let hasAccessorError = diagnoseAccessorNameErrors(
			in: providerResult.descriptors,
			memberNames: memberNames,
			context: context
		)

		guard !providerResult.hasError, !hasAccessorError else {
			return []
		}

		return providerResult.descriptors.map { provider in
			// graph 접근 수준을 포함한 생성 접근자 선언부
			let accessorSignature = "\(graphAccess.rawValue) func \(provider.accessorName)()"
			// 선언 순서와 외부 레이블을 보존한 provider factory 인자
			let arguments = provider.parameters.map(\.factoryArgument).joined(separator: ", ")

			return DeclSyntax(
				"""
				\(raw: accessorSignature) -> \(raw: provider.returnType.trimmedDescription) {
				    \(raw: provider.factoryName)(\(raw: arguments))
				}
				"""
			)
		}
	}

	// graph 본체의 `@Provide` factory 검증과 수집
	private static func providers(
		in graph: ClassDeclSyntax,
		context: some MacroExpansionContext
	) -> (descriptors: [ProviderDescriptor], hasError: Bool) {
		var hasError = false
		var descriptors: [ProviderDescriptor] = []

		for member in graph.memberBlock.members {
			guard let attribute = provideAttribute(in: member.decl) else {
				continue
			}
			guard let function = member.decl.as(FunctionDeclSyntax.self) else {
				context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderDeclaration))
				hasError = true
				continue
			}

			guard let provider = providerDescriptor(
				from: function,
				attribute: attribute,
				in: context
			) else {
				hasError = true
				continue
			}

			descriptors.append(provider)
		}

		return (descriptors, hasError)
	}

	// 생성 접근자 이름 중복과 기존 member 충돌 진단
	private static func diagnoseAccessorNameErrors(
		in providers: [ProviderDescriptor],
		memberNames: Set<String>,
		context: some MacroExpansionContext
	) -> Bool {
		let counts = providers.reduce(into: [String: Int]()) { counts, provider in
			counts[provider.accessorName, default: 0] += 1
		}

		var hasError = false
		for provider in providers {
			if counts[provider.accessorName] != 1 {
				context.diagnose(Diagnostic(node: provider.attribute, message: CradleMacroDiagnostic.duplicateAccessor))
				hasError = true
			}
			if memberNames.contains(provider.accessorName) {
				context.diagnose(Diagnostic(node: provider.attribute, message: CradleMacroDiagnostic.existingMemberCollision))
				hasError = true
			}
		}

		return hasError
	}

	// 정상 provider 문법을 접근자 생성 정보로 변환
	private static func providerDescriptor(
		from function: FunctionDeclSyntax,
		attribute: AttributeSyntax,
		in context: some MacroExpansionContext
	) -> ProviderDescriptor? {
		guard isPrivate(function) else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderDeclaration))
			return nil
		}
		guard !isTypeMember(function),
			function.genericParameterClause == nil,
			function.genericWhereClause == nil,
			function.signature.effectSpecifiers == nil else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderSignature))
			return nil
		}
		guard let parameters = providerParameterDescriptors(
			from: function.signature.parameterClause.parameters
		) else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderParameter))
			return nil
		}
		guard let returnClause = function.signature.returnClause,
			function.body != nil else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.missingProviderResultOrBody))
			return nil
		}
		guard let accessorName = accessorName(for: returnClause.type) else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.unsupportedProviderResult))
			return nil
		}
		guard isValidAccessorName(accessorName) else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidAccessorName))
			return nil
		}

		return ProviderDescriptor(
			attribute: attribute,
			factoryName: function.name.text,
			returnType: returnClause.type,
			accessorName: accessorName,
			parameters: parameters
		)
	}

	// final class graph 판별
	private static func isFinal(_ graph: ClassDeclSyntax) -> Bool {
		graph.modifiers.contains { modifier in
			modifier.name.tokenKind == .keyword(.final)
		}
	}

	// private provider 판별
	private static func isPrivate(_ function: FunctionDeclSyntax) -> Bool {
		function.modifiers.contains { modifier in
			modifier.name.tokenKind == .keyword(.private)
		}
	}

	// static 또는 class provider 판별
	private static func isTypeMember(_ function: FunctionDeclSyntax) -> Bool {
		function.modifiers.contains { modifier in
			modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
		}
	}
}
