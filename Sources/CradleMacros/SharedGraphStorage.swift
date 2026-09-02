//
//  SharedGraphStorage.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// graph 생성 전에 shared Factory 결과를 보관하는 타입 지정 저장소 생성
struct SharedGraphStorage {
	// 중첩 저장소 타입 이름
	let storageTypeName: TokenSyntax
	// graph가 저장소를 소유할 프로퍼티 이름
	let storagePropertyName: TokenSyntax
	// 정적 builder 호출에 사용할 graph 타입 이름
	let graphName: TokenSyntax
	// shared 저장소를 생성할 정적 함수 이름
	let builderName: TokenSyntax
	// 등록 순서로 보관한 shared Factory
	let providers: [ProviderDescriptor]
	// 의존성 타입 identity와 생성 프로퍼티 이름 연결
	let propertyNames: [RegisteredTypeIdentity: String]
	// 등록별 복제 static Factory helper 이름
	let helperNames: [RegisteredTypeIdentity: TokenSyntax]

	// 한 graph의 shared Factory와 충돌하지 않는 저장소 식별자 생성
	init(
		graphName: TokenSyntax,
		providers: [ProviderDescriptor],
		propertyNames: [RegisteredTypeIdentity: String],
		in context: some MacroExpansionContext
	) {
		storageTypeName = context.makeUniqueName("SharedStorage")
		storagePropertyName = context.makeUniqueName("sharedStorage")
		self.graphName = graphName
		builderName = context.makeUniqueName("makeSharedStorage")
		self.providers = providers
		self.propertyNames = propertyNames
		helperNames = Dictionary(uniqueKeysWithValues: providers.map { provider in
			(provider.registrationIdentity, context.makeUniqueName("makeShared\(provider.propertyIdentifier)"))
		})
	}

	// 중첩 저장소·정적 helper·즉시 초기화 소유 프로퍼티 선언 생성
	func declarations() -> [DeclSyntax] {
		[storageDeclaration()]
			+ providers.compactMap { helperDeclaration(for: $0) }
			+ [builderDeclaration(), storagePropertyDeclaration()]
	}

	// shared 생성 프로퍼티가 읽을 저장소 값 참조
	func valueReference(for provider: ProviderDescriptor) -> String {
		"\(storagePropertyName.trimmedDescription).\(provider.propertyName)"
	}

	// shared 결과를 담는 모든 타입 지정 let 선언
	private func storageDeclaration() -> DeclSyntax {
		let fields = providers.map { provider in
			"let \(provider.propertyName): \(provider.returnType.trimmedDescription)"
		}.joined(separator: "\n")
		return DeclSyntax(
			"""
			private struct \(storageTypeName) {
			    \(raw: fields)
			}
			"""
		)
	}

	// 명시 본문 또는 bodyless initializer를 static helper로 복제
	private func helperDeclaration(for provider: ProviderDescriptor) -> DeclSyntax? {
		guard let helperName = helperNames[provider.registrationIdentity],
			let body = sharedHelperBody(for: provider.factory) else {
			return nil
		}
		return DeclSyntax(
			"""
			private static func \(helperName)\(raw: provider.factory.signature.parameterClause.trimmedDescription) -> \(raw: provider.returnType.trimmedDescription) \(raw: body)
			"""
		)
	}

	// shared 결과를 위상 순서의 지역 let으로 만들고 저장소 생성
	private func builderDeclaration() -> DeclSyntax {
		let orderedProviders = sharedDependencyOrder(in: providers)
		let constructions = orderedProviders.map { provider in
			let helper = helperNames[provider.registrationIdentity]!.trimmedDescription
			let arguments = provider.parameters.map { parameter in
				parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity]!)
			}.joined(separator: ", ")
			return "let \(provider.propertyName): \(provider.returnType.trimmedDescription) = \(helper)(\(arguments))"
		}.joined(separator: "\n")
		let arguments = providers.map { provider in
			"\(provider.propertyName): \(provider.propertyName)"
		}.joined(separator: ", ")
		return DeclSyntax(
			"""
			private static func \(builderName)() -> \(storageTypeName) {
			    \(raw: constructions)
			    return \(storageTypeName)(\(raw: arguments))
			}
			"""
		)
	}

	// graph 초기화 전에 builder를 실행하는 기본값 저장 프로퍼티
	private func storagePropertyDeclaration() -> DeclSyntax {
		"""
		private let \(storagePropertyName) = \(graphName).\(builderName)()
		"""
	}
}

// 명시 본문에서 #function을 원래 Factory 식별자로 보존하는 rewriter
private final class SharedFunctionNameRewriter: SyntaxRewriter {
	// 원래 Factory의 #function 결과
	private let functionIdentifier: String

	init(functionIdentifier: String) {
		self.functionIdentifier = functionIdentifier
	}

	override func visit(_ node: DeclReferenceExprSyntax) -> ExprSyntax {
		guard node.trimmedDescription == "#function" else {
			return super.visit(node)
		}
		return ExprSyntax(StringLiteralExprSyntax(content: functionIdentifier))
	}

	override func visit(_ node: MacroExpansionExprSyntax) -> ExprSyntax {
		guard node.trimmedDescription == "#function" else {
			return super.visit(node)
		}
		return ExprSyntax(StringLiteralExprSyntax(content: functionIdentifier))
	}

	override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}
}

// static helper가 사용할 Factory 본문 문자열 생성
func sharedHelperBody(for factory: FunctionDeclSyntax) -> String? {
	if let body = factory.body {
		let rewriter = SharedFunctionNameRewriter(
			functionIdentifier: originalFunctionIdentifier(for: factory)
		)
		return rewriter.rewrite(body, detach: true).trimmedDescription
	}
	guard let generated = generatedProviderBody(for: factory) else {
		return nil
	}
	let items = generated.map(\.trimmedDescription).joined(separator: "\n")
	return "{\n\(items)\n}"
}

// #function이 반환할 원래 Factory 이름과 외부 인자 레이블 구성
private func originalFunctionIdentifier(for factory: FunctionDeclSyntax) -> String {
	let name = factory.name.identifier?.name ?? factory.name.text
	let labels = factory.signature.parameterClause.parameters.map { parameter in
		let label = parameter.firstName.identifier?.name ?? parameter.firstName.text
		return "\(label):"
	}.joined()
	return "\(name)(\(labels))"
}
