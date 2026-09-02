//
//  SharedDependencyOrderTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import Testing
@testable import CradleMacros

// chain과 diamond의 shared Factory를 의존성 순서로 배치하는지 확인
@Test
func sharedDependencyOrderSortsDependenciesBeforeConsumers() throws {
	let providers = [
		try sharedProvider(name: "Root", dependencies: ["First", "Second"]),
		try sharedProvider(name: "First", dependencies: ["Leaf"]),
		try sharedProvider(name: "Second", dependencies: ["Leaf"]),
		try sharedProvider(name: "Leaf")
	]

	#expect(sharedDependencyOrder(in: providers).map(\.propertyIdentifier) == ["leaf", "first", "second", "root"])
}

// transient 등록은 shared 저장소 생성 순서에서 제외하는지 확인
@Test
func sharedDependencyOrderExcludesTransientProviders() throws {
	let providers = [
		try sharedProvider(name: "Shared"),
		try sharedProvider(name: "Transient", lifetime: .transient)
	]

	#expect(sharedDependencyOrder(in: providers).map(\.propertyIdentifier) == ["shared"])
}

// 순서 계산 전 검증을 통과한 Factory descriptor 생성
private func sharedProvider(
	name: String,
	dependencies: [String] = [],
	lifetime: ProviderLifetime = .shared
) throws -> ProviderDescriptor {
	let returnType = TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
	let parameters = dependencies.map { dependency in
		let type = TypeSyntax(IdentifierTypeSyntax(name: .identifier(dependency)))
		return ProviderParameterDescriptor(
			externalLabel: dependency.lowercased(),
			localName: dependency.lowercased(),
			localNameToken: .identifier(dependency.lowercased()),
			type: type,
			typeIdentity: registeredTypeIdentity(for: type)
		)
	}
	let factory = try FunctionDeclSyntax(
		"private func make\(raw: name)() -> \(raw: name) { fatalError() }"
	)
	return ProviderDescriptor(
		attribute: AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Provide"))),
		factory: factory,
		registeredType: RegisteredType(
			exposedType: returnType,
			identity: registeredTypeIdentity(for: returnType),
			propertyName: name.lowercased()
		),
		parameters: parameters,
		lifetime: lifetime
	)
}
