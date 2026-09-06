//
//  LazyGraphStorage.swift
//  CradleMacros
//
//  Created by opfic on 9/6/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// graph 인스턴스별 lazy Factory 결과를 보관하는 타입 지정 저장소 생성
struct LazyGraphStorage {
	// lazy 결과를 보관할 등록
	let providers: [ProviderDescriptor]
	// 등록 타입 identity와 생성 프로퍼티 이름 연결
	let propertyNames: [RegisteredTypeIdentity: String]
	// 등록별 충돌 없는 lazy 저장 프로퍼티 이름
	let storageNames: [RegisteredTypeIdentity: TokenSyntax]

	// lazy 등록과 호출 인자를 보관할 저장소 정보 생성
	init(
		providers: [ProviderDescriptor],
		propertyNames: [RegisteredTypeIdentity: String],
		in context: some MacroExpansionContext
	) {
		self.providers = providers.filter { $0.lifetime == .lazy }
		self.propertyNames = propertyNames
		storageNames = Dictionary(uniqueKeysWithValues: self.providers.map { provider in
			(
				provider.registrationIdentity,
				lazyStorageName(in: context)
			)
		})
	}

	// graph가 보관할 모든 lazy 저장 프로퍼티 선언 생성
	func declarations() -> [DeclSyntax] {
		providers.compactMap(storageDeclaration)
	}

	// lazy 생성 프로퍼티가 읽을 graph 소유 결과 참조
	func valueReference(for provider: ProviderDescriptor) -> String? {
		storageNames[provider.registrationIdentity]?.trimmedDescription
	}

	// 원본 Factory 호출을 최초 접근에 실행하는 lazy 저장 프로퍼티 선언
	private func storageDeclaration(for provider: ProviderDescriptor) -> DeclSyntax? {
		guard let storageName = storageNames[provider.registrationIdentity] else {
			return nil
		}
		let arguments = provider.parameters.map { parameter in
			parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity])
		}.joined(separator: ", ")
		return DeclSyntax(
			"""
			private lazy var \(storageName): \(raw: provider.returnType.trimmedDescription) = \(raw: provider.factoryName)(\(raw: arguments))
			"""
		)
	}
}

// 타입 이름과 무관하게 고유한 lazy 저장 식별자 생성
private func lazyStorageName(in context: some MacroExpansionContext) -> TokenSyntax {
	context.makeUniqueName("lazyStorage")
}
