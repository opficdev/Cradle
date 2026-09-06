//
//  ProviderDeclaration.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// 등록 타입 identity와 생성 접근자 이름 연결 생성
func propertyNames(for providers: [ProviderDescriptor]) -> [RegisteredTypeIdentity: String] {
	Dictionary(uniqueKeysWithValues: providers.map { ($0.registrationIdentity, $0.propertyName) })
}

// shared 등록이 있을 때만 graph 전용 저장소 생성
func sharedStorage(
	for providers: [ProviderDescriptor],
	graphName: TokenSyntax,
	sources: [SourceGraphDescriptor],
	propertyNames: [RegisteredTypeIdentity: String],
	in context: some MacroExpansionContext
) -> SharedGraphStorage? {
	let sharedProviders = providers.filter { $0.lifetime == .shared }
	guard !sharedProviders.isEmpty else {
		return nil
	}
	return SharedGraphStorage(
		graphName: graphName,
		providers: sharedProviders,
		sources: sources,
		propertyNames: propertyNames,
		in: context
	)
}

// 일반 생성 프로퍼티와 외부 입력 생성 메서드 선언 생성
func providerDeclarations(
	for providers: [ProviderDescriptor],
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: SharedGraphStorage?,
	lazyStorage: LazyGraphStorage
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
			storage: storage,
			lazyStorage: lazyStorage
		)
	}
	return (storage?.declarations() ?? []) + lazyStorage.declarations() + declarations
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
		parameter.factoryArgument(
			propertyName: propertyNames[parameter.typeIdentity],
			qualifyingGraphMember: true
		)
	}.joined(separator: ", ")
	return DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) func \(raw: provider.propertyName)(\(raw: parameters)) -> \(raw: provider.returnType.trimmedDescription) {
		    self.\(raw: provider.factoryName)(\(raw: arguments))
		}
		"""
	)
}

// 수명에 맞는 일반 provider 생성 프로퍼티 선언
private func propertyDeclaration(
	for provider: ProviderDescriptor,
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: SharedGraphStorage?,
	lazyStorage: LazyGraphStorage
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
	if provider.lifetime == .lazy,
		let valueReference = lazyStorage.valueReference(for: provider) {
		return DeclSyntax(
			"""
			\(raw: signature): \(raw: provider.returnType.trimmedDescription) {
			    \(raw: valueReference)
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
