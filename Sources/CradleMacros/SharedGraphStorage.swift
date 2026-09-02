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
	// 조합 graph가 보관하는 source graph
	let sources: [SourceGraphDescriptor]
	// 의존성 타입 identity와 생성 프로퍼티 이름 연결
	let propertyNames: [RegisteredTypeIdentity: String]
	// 등록별 복제 static Factory helper 이름
	let helperNames: [RegisteredTypeIdentity: TokenSyntax]
	// 등록별 source 저장 프로퍼티 참조
	let sourceReferences: [RegisteredTypeIdentity: SourceGraphReferences]
	// 등록별 실제 참조 source graph
	let providerSources: [RegisteredTypeIdentity: [SourceGraphDescriptor]]
	// 등록별 source graph helper 매개변수 이름
	let helperSourceNames: [RegisteredTypeIdentity: [RegisteredTypeIdentity: TokenSyntax]]

	// 한 graph의 shared Factory와 충돌하지 않는 저장소 식별자 생성
	init(
		graphName: TokenSyntax,
		providers: [ProviderDescriptor],
		sources: [SourceGraphDescriptor],
		propertyNames: [RegisteredTypeIdentity: String],
		in context: some MacroExpansionContext
	) {
		storageTypeName = context.makeUniqueName("SharedStorage")
		storagePropertyName = context.makeUniqueName("sharedStorage")
		self.graphName = graphName
		builderName = context.makeUniqueName("makeSharedStorage")
		self.providers = providers
		self.sources = sources
		self.propertyNames = propertyNames
		helperNames = Dictionary(uniqueKeysWithValues: providers.map { provider in
			(provider.registrationIdentity, context.makeUniqueName("makeShared\(provider.propertyIdentifier)"))
		})
		let sourceNames = Set(sources.map(\.propertyIdentifier))
		let references = Dictionary(uniqueKeysWithValues: providers.map { provider in
			(provider.registrationIdentity, sourceGraphReferences(in: provider.factory, sourceNames: sourceNames))
		})
		sourceReferences = references
		let providerSources = Dictionary(uniqueKeysWithValues: providers.map { provider in
			let names = references[provider.registrationIdentity]?.sourceNames ?? []
			return (provider.registrationIdentity, sources.filter { names.contains($0.propertyIdentifier) })
		})
		self.providerSources = providerSources
		helperSourceNames = Dictionary(uniqueKeysWithValues: providers.map { provider in
			let names = Dictionary(uniqueKeysWithValues: (providerSources[provider.registrationIdentity] ?? []).map { source in
				(source.identity, sourceHelperParameterName(for: source, in: context))
			})
			return (provider.registrationIdentity, names)
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

	// source graph를 받아야 하는 shared builder 여부
	var requiresSourceInitialization: Bool {
		!builderSources.isEmpty
	}

	// source 저장 프로퍼티 대입 뒤 실행할 shared 저장소 초기화문
	func initializationAssignment() -> String? {
		guard requiresSourceInitialization else {
			return nil
		}
		let arguments = builderSources.map { source in
			"\(source.propertyName): \(source.propertyName)"
		}.joined(separator: ", ")
		return "self.\(storagePropertyName.trimmedDescription) = \(graphName.trimmedDescription).\(builderName.trimmedDescription)(\(arguments))"
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
			let body = sharedHelperBody(
				for: provider.factory,
				references: sourceReferences[provider.registrationIdentity],
				sourceParameterNames: sourceParameterNames(for: provider)
			) else {
			return nil
		}
		let parameters = provider.factory.signature.parameterClause.parameters.map { parameter in
			parameter.with(\.trailingComma, nil).trimmedDescription
		}
			+ helperSources(for: provider).compactMap { source in
				guard let name = helperSourceNames[provider.registrationIdentity]?[source.identity] else {
					return nil
				}
				return "\(name.trimmedDescription): \(source.type.trimmedDescription)"
			}
		return DeclSyntax(
			"""
			private static func \(helperName)(\(raw: parameters.joined(separator: ", "))) -> \(raw: provider.returnType.trimmedDescription) \(raw: body)
			"""
		)
	}

	// shared 결과를 위상 순서의 지역 let으로 만들고 저장소 생성
	private func builderDeclaration() -> DeclSyntax {
		let orderedProviders = sharedDependencyOrder(in: providers)
		let constructions = orderedProviders.map { provider in
			let helper = helperNames[provider.registrationIdentity]!.trimmedDescription
			let providerArguments = provider.parameters.map { parameter in
				parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity]!)
			}
			let sourceArguments = helperSources(for: provider).compactMap { source -> String? in
				guard let name = helperSourceNames[provider.registrationIdentity]?[source.identity] else {
					return nil
				}
				return "\(name.trimmedDescription): \(source.propertyName)"
			}
			let arguments = (providerArguments + sourceArguments).joined(separator: ", ")
			return "let \(provider.propertyName): \(provider.returnType.trimmedDescription) = \(helper)(\(arguments))"
		}.joined(separator: "\n")
		let arguments = providers.map { provider in
			"\(provider.propertyName): \(provider.propertyName)"
		}.joined(separator: ", ")
		let parameters = builderSources.map { source in
			"\(source.propertyName): \(source.type.trimmedDescription)"
		}.joined(separator: ", ")
		return DeclSyntax(
			"""
			private static func \(builderName)(\(raw: parameters)) -> \(storageTypeName) {
			    \(raw: constructions)
			    return \(storageTypeName)(\(raw: arguments))
			}
			"""
		)
	}

	// graph 초기화 전에 builder를 실행하는 기본값 저장 프로퍼티
	private func storagePropertyDeclaration() -> DeclSyntax {
		if requiresSourceInitialization {
			return DeclSyntax(
				"""
				private let \(storagePropertyName): \(storageTypeName)
				"""
			)
		}
		return """
		private let \(storagePropertyName) = \(graphName).\(builderName)()
		"""
	}

	// 모든 shared Factory가 실제로 참조한 source graph
	private var builderSources: [SourceGraphDescriptor] {
		sources.filter { source in
			helperSourceNames.values.contains { names in
				names[source.identity] != nil
			}
		}
	}

	// 한 shared Factory가 실제로 참조한 source graph
	private func helperSources(for provider: ProviderDescriptor) -> [SourceGraphDescriptor] {
		providerSources[provider.registrationIdentity] ?? []
	}

	// Factory source 이름과 helper 매개변수 이름 연결
	private func sourceParameterNames(for provider: ProviderDescriptor) -> [String: String] {
		Dictionary(uniqueKeysWithValues: helperSources(for: provider).compactMap { source in
			guard let name = helperSourceNames[provider.registrationIdentity]?[source.identity] else {
				return nil
			}
			return (source.propertyIdentifier, name.trimmedDescription)
		})
	}
}

// helper 매개변수로 사용할 유효한 고유 identifier 생성
private func sourceHelperParameterName(
	for source: SourceGraphDescriptor,
	in context: some MacroExpansionContext
) -> TokenSyntax {
	let uniqueName = context.makeUniqueName("source\(source.propertyIdentifier)").trimmedDescription
	let identifier = uniqueName.unicodeScalars.map { scalar in
		if scalar == "_" || scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
			String(scalar)
		} else {
			"_"
		}
	}.joined()
	return .identifier(identifier)
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

	// 지역 initializer의 #function 문맥 보존
	override func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 deinitializer의 #function 문맥 보존
	override func visit(_ node: DeinitializerDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 accessor의 #function 문맥 보존
	override func visit(_ node: AccessorDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 subscript의 #function 문맥 보존
	override func visit(_ node: SubscriptDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 struct와 내부 선언의 #function 문맥 보존
	override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 class와 내부 선언의 #function 문맥 보존
	override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 enum과 내부 선언의 #function 문맥 보존
	override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 actor와 내부 선언의 #function 문맥 보존
	override func visit(_ node: ActorDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 지역 protocol과 내부 선언의 #function 문맥 보존
	override func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}

	// 중첩 extension과 내부 선언의 #function 문맥 보존
	override func visit(_ node: ExtensionDeclSyntax) -> DeclSyntax {
		DeclSyntax(node)
	}
}

// static helper가 사용할 Factory 본문 문자열 생성
func sharedHelperBody(
	for factory: FunctionDeclSyntax,
	references: SourceGraphReferences? = nil,
	sourceParameterNames: [String: String] = [:]
) -> String? {
	if let body = factory.body {
		let sourceRewrittenBody: CodeBlockSyntax
		if let references {
			sourceRewrittenBody = rewrittenSourceGraphFactoryBody(
				body,
				references: references,
				parameterNames: sourceParameterNames
			)
		} else {
			sourceRewrittenBody = body
		}
		let rewriter = SharedFunctionNameRewriter(
			functionIdentifier: originalFunctionIdentifier(for: factory)
		)
		return rewriter.rewrite(sourceRewrittenBody, detach: true).trimmedDescription
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
