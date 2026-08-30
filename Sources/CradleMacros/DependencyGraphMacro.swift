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
		// 중복 검증을 통과한 식별자와 생성 접근자 원문 표기 연결
		let accessorNames = Dictionary(uniqueKeysWithValues: providerResult.descriptors.map { provider in
			(provider.accessorIdentifier, provider.accessorName)
		})
		guard !diagnoseProviderParameterErrors(
			in: providerResult.descriptors,
			accessorNames: accessorNames,
			context: context
		) else {
			return []
		}

		return providerResult.descriptors.map { provider in
			// graph 접근 수준을 포함한 생성 접근자 선언부
			let accessorSignature = "\(graphAccess.rawValue) func \(provider.accessorName)()"
			// 연결 검증을 통과한 접근자로 선언 순서와 외부 레이블을 보존한 factory 인자 생성
			let arguments = provider.parameters.map { parameter in
				parameter.factoryArgument(accessorName: accessorNames[parameter.localName]!)
			}.joined(separator: ", ")

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
		// 같은 생성 접근자의 원본 등록을 선언 순서대로 보관
		let groups = Dictionary(grouping: providers, by: \.accessorIdentifier)
		// 이미 오류를 표시한 중복 그룹의 식별자
		var reported = Set<String>()
		// 중복 등록 또는 기존 멤버 충돌 포함 여부
		var hasError = false
		for provider in providers {
			// 현재 등록의 백틱 정규화 접근자 식별자
			let identifier = provider.accessorIdentifier
			// 중복 그룹의 첫 등록에서만 원본 반환 타입 오류 발행
			if let group = groups[identifier], 1 < group.count, reported.insert(identifier).inserted {
				// 대표를 포함한 모든 충돌 Factory의 등록 위치 연결
				let notes = group.map { registration in
					Note(
						node: Syntax(registration.attribute),
						message: DuplicateRegistrationProviderNote(
							factoryName: registration.factoryName,
							returnType: registration.returnType.trimmedDescription
						)
					)
				}
				context.diagnose(
					Diagnostic(
						node: provider.returnType,
						message: DuplicateRegistrationDiagnostic(accessorIdentifier: identifier),
						notes: notes
					)
				)
				hasError = true
			}
			if memberNames.contains(provider.accessorName) {
				context.diagnose(Diagnostic(node: provider.attribute, message: CradleMacroDiagnostic.existingMemberCollision))
				hasError = true
			}
		}

		return hasError
	}

	// provider 생성 접근자 집합에 없는 매개변수 연결 진단
	private static func diagnoseProviderParameterErrors(
		in providers: [ProviderDescriptor],
		accessorNames: [String: String],
		context: some MacroExpansionContext
	) -> Bool {
		// provider 매개변수 연결 오류 포함 여부
		var hasError = false

		for provider in providers {
			for parameter in provider.parameters where accessorNames[parameter.localName] == nil {
				context.diagnose(
					Diagnostic(
						node: parameter.localNameToken,
						message: MissingRegistrationDiagnostic(
							factoryName: provider.factoryName,
							localName: parameter.localName
						),
						notes: [
							Note(
								node: Syntax(provider.attribute),
								message: MissingRegistrationProviderNote(factoryName: provider.factoryName)
							)
						]
					)
				)
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
