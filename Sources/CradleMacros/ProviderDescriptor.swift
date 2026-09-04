//
//  ProviderDescriptor.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// `@Provide` Factory의 반환 타입 기반 등록 정보
struct ProviderDescriptor {
	// 오류 위치로 사용할 `@Provide` attribute
	let attribute: AttributeSyntax
	// graph 본체에 선언된 원본 Factory
	let factory: FunctionDeclSyntax
	// 생성 프로퍼티와 provider edge에 사용할 반환 등록 정보
	let registeredType: RegisteredType
	// provider Factory 호출에 사용할 매개변수
	let parameters: [ProviderParameterDescriptor]
	// Factory 결과를 graph에 보관할지 결정하는 수명
	let lifetime: ProviderLifetime

	// graph 등록으로 연결할 Factory 매개변수
	var graphParameters: [ProviderParameterDescriptor] {
		parameters.filter { !$0.isExternal }
	}

	// 생성 메서드 호출자가 전달할 Factory 매개변수
	var externalParameters: [ProviderParameterDescriptor] {
		parameters.filter(\.isExternal)
	}

	// 일반 생성 프로퍼티 대신 생성 메서드가 필요한지 여부
	var hasExternalParameters: Bool {
		parameters.contains(where: \.isExternal)
	}

	// 진단과 호출에 사용할 Factory 이름
	var factoryName: String { factory.name.text }

	// 생성 프로퍼티가 그대로 노출할 반환 타입
	var returnType: TypeSyntax { registeredType.exposedType }

	// 등록 연결과 중복 검사에 사용할 identity
	var registrationIdentity: RegisteredTypeIdentity { registeredType.identity }

	// 반환 타입에서 만든 생성 프로퍼티 이름
	var propertyName: String { registeredType.propertyName }

	// 백틱 표기를 제외한 생성 프로퍼티 비교용 식별자
	var propertyIdentifier: String {
		guard propertyName.hasPrefix("`"), propertyName.hasSuffix("`") else {
			return propertyName
		}
		return String(propertyName.dropFirst().dropLast())
	}
}

// 정상 provider 문법을 반환 타입 등록 정보로 변환
func providerDescriptor(
	from function: FunctionDeclSyntax,
	attribute: AttributeSyntax,
	in context: some MacroExpansionContext
) -> ProviderDescriptor? {
	guard validateProviderDeclaration(function, attribute: attribute, context: context),
		let parameters = validatedProviderParameters(function, attribute: attribute, context: context),
		let registeredType = validatedProviderReturnType(function, attribute: attribute, context: context),
		let lifetime = providerLifetime(from: attribute, in: context) else {
		return nil
	}
	let provider = ProviderDescriptor(
		attribute: attribute,
		factory: function,
		registeredType: registeredType,
		parameters: parameters,
		lifetime: lifetime
	)
	guard validateExternalProviderLifetime(provider, context: context) else {
		return nil
	}
	return provider
}

// Factory 선언과 효과 제약 검증
private func validateProviderDeclaration(
	_ function: FunctionDeclSyntax,
	attribute: AttributeSyntax,
	context: some MacroExpansionContext
) -> Bool {
	guard function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }) else {
		context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderDeclaration))
		return false
	}
	let isTypeMember = function.modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
	}
	guard !isTypeMember,
		function.genericParameterClause == nil,
		function.genericWhereClause == nil,
		function.signature.effectSpecifiers == nil else {
		context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderSignature))
		return false
	}
	return true
}

// Optional과 지원하지 않는 매개변수 형식 검증
private func validatedProviderParameters(
	_ function: FunctionDeclSyntax,
	attribute: AttributeSyntax,
	context: some MacroExpansionContext
) -> [ProviderParameterDescriptor]? {
	for parameter in function.signature.parameterClause.parameters where isDirectOptionalType(parameter.type) {
		context.diagnose(Diagnostic(node: parameter.type, message: InvalidProviderTypeDiagnostic()))
		return nil
	}
	for parameter in function.signature.parameterClause.parameters
	where containsAttribute(named: "External", in: parameter.attributes) {
		let name = parameter.secondName ?? parameter.firstName
		let localName = name.identifier?.name ?? name.text
		guard providerParameterIsSupported(parameter), localName != "_" else {
			context.diagnose(Diagnostic(node: parameter, message: InvalidExternalParameterDiagnostic()))
			return nil
		}
	}
	guard let parameters = providerParameterDescriptors(from: function.signature.parameterClause.parameters) else {
		context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderParameter))
		return nil
	}
	return parameters
}

// 외부 입력 Factory의 명시적 transient 수명 확인
private func validateExternalProviderLifetime(
	_ provider: ProviderDescriptor,
	context: some MacroExpansionContext
) -> Bool {
	guard provider.hasExternalParameters, provider.lifetime != .transient else {
		return true
	}
	for parameter in provider.externalParameters {
		guard let external = parameter.externalAttribute else {
			continue
		}
		context.diagnose(
			Diagnostic(
				node: external,
				message: ExternalRequiresTransientDiagnostic(),
				notes: [
					Note(
						node: Syntax(provider.attribute),
						message: ExternalProviderLifetimeNote(factoryName: provider.factoryName)
					)
				]
			)
		)
	}
	return false
}

// 반환 타입을 등록·생성 프로퍼티 타입으로 검증
private func validatedProviderReturnType(
	_ function: FunctionDeclSyntax,
	attribute: AttributeSyntax,
	context: some MacroExpansionContext
) -> RegisteredType? {
	guard let returnType = function.signature.returnClause?.type else {
		context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.missingProviderResult))
		return nil
	}
	guard !isDirectOptionalType(returnType) else {
		context.diagnose(Diagnostic(node: returnType, message: InvalidProviderTypeDiagnostic()))
		return nil
	}
	guard let registeredType = registeredType(for: returnType) else {
		context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.unsupportedProviderResult))
		return nil
	}
	guard isValidAccessorName(registeredType.propertyName) else {
		context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidAccessorName))
		return nil
	}
	return registeredType
}
