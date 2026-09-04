//
//  ProviderDeclaration.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// 일반 생성 프로퍼티와 외부 입력 생성 메서드 선언 생성
func providerDeclarations(
	for providers: [ProviderDescriptor],
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: SharedGraphStorage?
) -> [DeclSyntax] {
	let declarations = providers.map { provider in
		if provider.hasExternalParameters {
			return externalMethodDeclaration(
				for: provider,
				accessLevel: accessLevel,
				propertyNames: propertyNames
			)
		}
		return propertyDeclaration(
			for: provider,
			accessLevel: accessLevel,
			propertyNames: propertyNames,
			storage: storage
		)
	}
	return (storage?.declarations() ?? []) + declarations
}

// 호출자 입력만 노출하고 원본 Factory를 호출하는 생성 메서드 선언
private func externalMethodDeclaration(
	for provider: ProviderDescriptor,
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String]
) -> DeclSyntax {
	let parameters = provider.externalParameters.compactMap { parameter in
		parameter.externalMethodParameter()
	}.joined(separator: ", ")
	let arguments = provider.parameters.map { parameter in
		parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity])
	}.joined(separator: ", ")
	return DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) func \(raw: provider.propertyName)(\(raw: parameters)) -> \(raw: provider.returnType.trimmedDescription) {
		    \(raw: provider.factoryName)(\(raw: arguments))
		}
		"""
	)
}

// 수명에 맞는 일반 provider 생성 프로퍼티 선언
private func propertyDeclaration(
	for provider: ProviderDescriptor,
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: SharedGraphStorage?
) -> DeclSyntax {
	let signature = "\(accessLevel.rawValue) var \(provider.propertyName)"
	if provider.lifetime == .shared, let storage {
		return DeclSyntax(
			"""
			\(raw: signature): \(raw: provider.returnType.trimmedDescription) {
			    \(raw: storage.valueReference(for: provider))
			}
			"""
		)
	}
	let arguments = provider.parameters.map { parameter in
		parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity])
	}.joined(separator: ", ")
	return DeclSyntax(
		"""
		\(raw: signature): \(raw: provider.returnType.trimmedDescription) {
		    \(raw: provider.factoryName)(\(raw: arguments))
		}
		"""
	)
}
