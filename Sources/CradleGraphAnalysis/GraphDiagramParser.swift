//
//  GraphDiagramParser.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// 모든 조건부 컴파일 절을 포함해 DependencyGraph Mermaid 모델 수집
package func graphDiagrams(in sourceFile: SourceFileSyntax) -> [GraphDiagram] {
	let collector = GraphDiagramCollector()
	collector.walk(sourceFile)
	return collector.diagrams
}

// source file의 lexical type 경로를 유지하는 graph 수집기
private final class GraphDiagramCollector: SyntaxVisitor {
	// 현재 선언 안쪽의 type 이름 경로
	private var typePath = [String]()
	// 수집한 graph를 source 선언 순서로 보관
	private(set) var diagrams = [GraphDiagram]()

	// sourceAccurate traversal로 모든 `#if` 절을 함께 방문
	init() {
		super.init(viewMode: .sourceAccurate)
	}

	// class graph 수집과 중첩 type 경로 관리
	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
		collectGraphIfNeeded(
			attributes: node.attributes,
			name: node.name,
			memberBlock: node.memberBlock
		)
		typePath.append(graphIdentifierName(node.name))
		return .visitChildren
	}

	// class type 경로 종료
	override func visitPost(_ node: ClassDeclSyntax) {
		typePath.removeLast()
	}

	// actor graph 수집과 중첩 type 경로 관리
	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
		collectGraphIfNeeded(
			attributes: node.attributes,
			name: node.name,
			memberBlock: node.memberBlock
		)
		typePath.append(graphIdentifierName(node.name))
		return .visitChildren
	}

	// actor type 경로 종료
	override func visitPost(_ node: ActorDeclSyntax) {
		typePath.removeLast()
	}

	// struct type 경로 관리
	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
		typePath.append(graphIdentifierName(node.name))
		return .visitChildren
	}

	// struct type 경로 종료
	override func visitPost(_ node: StructDeclSyntax) {
		typePath.removeLast()
	}

	// enum type 경로 관리
	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
		typePath.append(graphIdentifierName(node.name))
		return .visitChildren
	}

	// enum type 경로 종료
	override func visitPost(_ node: EnumDeclSyntax) {
		typePath.removeLast()
	}

	// extension 대상 type 경로 안쪽 graph의 lexical 이름 보존
	override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
		typePath.append(node.extendedType.trimmedDescription)
		return .visitChildren
	}

	// extension 대상 type 경로 종료
	override func visitPost(_ node: ExtensionDeclSyntax) {
		typePath.removeLast()
	}

	// `@DependencyGraph` class·actor의 산출물 제외 표식과 provider를 수집
	private func collectGraphIfNeeded(
		attributes: AttributeListSyntax,
		name: TokenSyntax,
		memberBlock: MemberBlockSyntax
	) {
		guard let attribute = graphAttribute(in: attributes),
			graphDiagramIsEnabled(in: attribute) else {
			return
		}
		let sources = graphDiagramSources(in: attribute)
		let providers = graphDiagramProviders(
			in: memberBlock,
			sourceNames: Set(sources.map(\.name))
		)
		diagrams.append(
			GraphDiagram(
				lexicalName: (typePath + [graphIdentifierName(name)]).joined(separator: "."),
				sourceOffset: graphSourceOffset(of: name),
				sources: sources,
				providers: providers
			)
		)
	}
}

// graph 본체의 직접 `@Provide` Factory만 수집
private final class GraphDiagramProviderCollector: SyntaxVisitor {
	// source 참조 분석에 사용할 graph 저장 프로퍼티 이름
	private let sourceNames: Set<String>
	// 중첩 type·function 안쪽 선언 제외 깊이
	private var nestedDepth = 0
	// graph 직접 member인 provider
	private(set) var providers = [GraphDiagramProvider]()

	init(sourceNames: Set<String>) {
		self.sourceNames = sourceNames
		super.init(viewMode: .sourceAccurate)
	}

	// 중첩 class 안쪽 Factory 제외
	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	// 중첩 class 깊이 종료
	override func visitPost(_ node: ClassDeclSyntax) {
		nestedDepth -= 1
	}

	// 중첩 actor 안쪽 Factory 제외
	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	// 중첩 actor 깊이 종료
	override func visitPost(_ node: ActorDeclSyntax) {
		nestedDepth -= 1
	}

	// 중첩 struct 안쪽 Factory 제외
	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	// 중첩 struct 깊이 종료
	override func visitPost(_ node: StructDeclSyntax) {
		nestedDepth -= 1
	}

	// 중첩 enum 안쪽 Factory 제외
	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	// 중첩 enum 깊이 종료
	override func visitPost(_ node: EnumDeclSyntax) {
		nestedDepth -= 1
	}

	// graph 직접 member의 `@Provide` Factory 수집
	override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
		guard nestedDepth == 0,
			let attribute = provideAttribute(in: node.attributes),
			let returnType = node.signature.returnClause?.type,
			!node.signature.parameterClause.parameters.contains(where: { parameter in
				graphExternalAttribute(in: parameter.attributes) != nil
			}) else {
			return .skipChildren
		}
		let dependencies = node.signature.parameterClause.parameters.map(\.type).map(graphTypeIdentity)
		let references = graphSourceReferences(in: node, sourceNames: sourceNames)
		providers.append(
			GraphDiagramProvider(
				factoryName: graphIdentifierName(node.name),
				typeName: returnType.trimmedDescription,
				identity: graphTypeIdentity(for: returnType),
				lifetime: graphProviderLifetime(in: attribute),
				dependencyIdentities: dependencies,
				sourceNames: references.sourceNames
			)
		)
		return .skipChildren
	}

	// 저장 프로퍼티 초기화식과 accessor 안쪽의 지역 Factory 제외
	override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	// initializer와 subscript 안쪽의 지역 Factory 제외
	override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}

// `@DependencyGraph` attribute 반환
private func graphAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
	attributes.compactMap { element in
		element.as(AttributeSyntax.self)
	}.first { attribute in
		if let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) {
			return graphIdentifierName(identifier.name) == "DependencyGraph"
		}
		guard let member = attribute.attributeName.as(MemberTypeSyntax.self),
			graphIdentifierName(member.name) == "DependencyGraph",
			let module = member.baseType.as(IdentifierTypeSyntax.self) else {
			return false
		}
		return graphIdentifierName(module.name) == "Cradle"
	}
}

// `@Provide` attribute 반환
private func provideAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
	attributes.compactMap { element in
		element.as(AttributeSyntax.self)
	}.first { attribute in
		attribute.attributeName.trimmedDescription == "Provide"
	}
}

// `diagram: false`만 Mermaid 산출물 대상에서 제외
private func graphDiagramIsEnabled(in attribute: AttributeSyntax) -> Bool {
	guard case let .argumentList(arguments)? = attribute.arguments,
		let argument = arguments.first(where: { argument in
			argument.label?.identifier?.name == "diagram"
		}),
		let literal = argument.expression.as(BooleanLiteralExprSyntax.self) else {
		return true
	}
	return literal.literal.text != "false"
}

// graph `sources` argument를 source 저장 프로퍼티 정보로 변환
private func graphDiagramSources(in attribute: AttributeSyntax) -> [GraphDiagramSource] {
	guard case let .argumentList(arguments)? = attribute.arguments,
		let argument = arguments.first(where: { argument in
			argument.label?.identifier?.name == "sources"
		}),
		let array = argument.expression.as(ArrayExprSyntax.self) else {
		return []
	}
	return array.elements.compactMap { element in
		guard let member = element.expression.as(MemberAccessExprSyntax.self),
			member.declName.baseName.text == "self",
			member.declName.argumentNames == nil,
			let base = member.base else {
			return nil
		}
		let type = TypeSyntax(stringLiteral: base.trimmedDescription)
		guard !type.hasError,
			let name = graphAccessorName(for: type),
			graphHasValidAccessorName(name) else {
			return nil
		}
		return GraphDiagramSource(
			name: name,
			typeName: type.trimmedDescription,
			identity: graphTypeIdentity(for: type)
		)
	}
}

// graph 본체의 모든 조건부 컴파일 절에서 직접 provider 수집
private func graphDiagramProviders(
	in memberBlock: MemberBlockSyntax,
	sourceNames: Set<String>
) -> [GraphDiagramProvider] {
	let collector = GraphDiagramProviderCollector(sourceNames: sourceNames)
	collector.walk(memberBlock)
	return collector.providers
}

// `@Provide` 수명 인자에서 Mermaid 표현용 수명 반환
private func graphProviderLifetime(in attribute: AttributeSyntax) -> GraphProviderLifetime {
	guard case let .argumentList(arguments)? = attribute.arguments,
		arguments.count == 1,
		let argument = arguments.first,
		argument.label == nil,
		let member = argument.expression.as(MemberAccessExprSyntax.self),
		member.base == nil,
		member.declName.baseName.text == "transient" else {
		return .shared
	}
	return .transient
}

// `@External` 또는 `@Cradle.External` marker 확인
private func graphExternalAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
	attributes.compactMap { element in
		element.as(AttributeSyntax.self)
	}.first { attribute in
		if let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) {
			return graphIdentifierName(identifier.name) == "External"
		}
		guard let member = attribute.attributeName.as(MemberTypeSyntax.self),
			graphIdentifierName(member.name) == "External",
			let module = member.baseType.as(IdentifierTypeSyntax.self) else {
			return false
		}
		return graphIdentifierName(module.name) == "Cradle"
	}
}

// 백틱을 제외한 식별자 문자열 반환
private func graphIdentifierName(_ token: TokenSyntax) -> String {
	token.identifier?.name ?? token.text
}
