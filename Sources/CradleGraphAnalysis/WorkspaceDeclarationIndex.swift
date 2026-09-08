//
//  WorkspaceDeclarationIndex.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// workspace target의 module과 dependency 정보
package struct WorkspaceTargetDescriptor: Hashable {
	// manifest target 식별자
	package let id: WorkspaceTargetID
	// 실제 Swift module 이름
	package let moduleName: String
	// 분석 범위를 제한하는 로컬 target dependency
	package let dependencyIDs: Set<WorkspaceTargetID>

	package init(id: WorkspaceTargetID, moduleName: String, dependencyIDs: Set<WorkspaceTargetID>) {
		self.id = id
		self.moduleName = moduleName
		self.dependencyIDs = dependencyIDs
	}
}

// source context를 보존한 graph 선언
package struct WorkspaceGraphDescriptor: Hashable {
	// graph의 workspace 선언 식별자
	package let id: WorkspaceDeclarationID
	// 기존 target Mermaid 모델
	package let diagram: GraphDiagram
	// graph가 선언된 source 정보
	package let context: WorkspaceSourceContext
	// 원본 graph 선언 위치
	package let location: WorkspaceSourceLocation

	package init(
		id: WorkspaceDeclarationID,
		diagram: GraphDiagram,
		context: WorkspaceSourceContext,
		location: WorkspaceSourceLocation
	) {
		self.id = id
		self.diagram = diagram
		self.context = context
		self.location = location
	}
}

// 이름 가림과 graph 연결에 사용할 모든 명목 선언
package struct WorkspaceNominalType: Hashable {
	// 명목 선언 식별자
	package let id: WorkspaceDeclarationID
	// 선언 source 정보
	package let context: WorkspaceSourceContext
	// 선언 위치
	package let location: WorkspaceSourceLocation

	package init(id: WorkspaceDeclarationID, context: WorkspaceSourceContext, location: WorkspaceSourceLocation) {
		self.id = id
		self.context = context
		self.location = location
	}
}

// target별 graph와 명목 선언 조회용 색인
package struct WorkspaceDeclarationIndex {
	// manifest target 정보
	package let targets: [WorkspaceTargetDescriptor]
	// 출력 대상 graph 선언
	package let graphs: [WorkspaceGraphDescriptor]
	// diagram: false graph 선언
	package let excludedGraphs: Set<WorkspaceDeclarationID>
	// 이름 가림 판단을 위한 명목 선언
	package let nominalTypes: [WorkspaceNominalType]
	// 조립 analyzer가 읽을 type 원본 선언
	package let typeDeclarations: [WorkspaceTypeDeclaration]

	package init(
		targets: [WorkspaceTargetDescriptor],
		graphs: [WorkspaceGraphDescriptor],
		excludedGraphs: Set<WorkspaceDeclarationID>,
		nominalTypes: [WorkspaceNominalType],
		typeDeclarations: [WorkspaceTypeDeclaration]
	) {
		self.targets = targets.sorted { $0.id < $1.id }
		self.graphs = graphs.sorted { $0.id < $1.id }
		self.excludedGraphs = excludedGraphs
		self.nominalTypes = nominalTypes.sorted { $0.id < $1.id }
		self.typeDeclarations = typeDeclarations.sorted { $0.id < $1.id }
	}

	// target 식별자로 target descriptor 조회
	package func target(for id: WorkspaceTargetID) -> WorkspaceTargetDescriptor? {
		targets.first { $0.id == id }
	}

	// 정확한 target·lexical 경로의 type 선언 조회
	package func typeDeclaration(for id: WorkspaceDeclarationID) -> WorkspaceTypeDeclaration? {
		typeDeclarations.first { $0.id == id }
	}
}

// 제한된 조립 구문 분석에 사용할 일반·graph type 원본 선언
package enum WorkspaceTypeDeclarationKind: Equatable {
	// class 선언
	case classType
	// actor 선언
	case actor
	// struct 선언
	case `struct`
	// enum 선언
	case `enum`
}

// 제한된 조립 구문 분석에 사용할 일반·graph type 원본 선언
package struct WorkspaceTypeDeclaration {
	// type 선언 식별자
	package let id: WorkspaceDeclarationID
	// source context
	package let context: WorkspaceSourceContext
	// 명목 선언의 종류
	package let kind: WorkspaceTypeDeclarationKind
	// 직접 member 선언 block
	package let memberBlock: MemberBlockSyntax
	// DependencyGraph input type 표기
	package let graphInputTypeName: String?

	package init(
		id: WorkspaceDeclarationID,
		context: WorkspaceSourceContext,
		kind: WorkspaceTypeDeclarationKind,
		memberBlock: MemberBlockSyntax,
		graphInputTypeName: String?
	) {
		self.id = id
		self.context = context
		self.kind = kind
		self.memberBlock = memberBlock
		self.graphInputTypeName = graphInputTypeName
	}
}

// source 구문에서 graph·제외 graph·명목 선언을 수집하는 collector
package final class WorkspaceDeclarationCollector {
	// target별 선언 누적 저장소
	private let targets: [WorkspaceTargetDescriptor]
	// 활성 graph 선언
	private var graphs = [WorkspaceGraphDescriptor]()
	// 제외 graph 선언
	private var excludedGraphs = Set<WorkspaceDeclarationID>()
	// 모든 명목 선언
	private var nominalTypes = [WorkspaceNominalType]()
	// 조립 분석에 사용할 type 원본 선언
	private var typeDeclarations = [WorkspaceTypeDeclaration]()

	package init(targets: [WorkspaceTargetDescriptor]) {
		self.targets = targets
	}

	// source 파일 하나의 선언을 색인에 추가
	package func collect(sourceFile: SourceFileSyntax, context: WorkspaceSourceContext) {
		let collector = WorkspaceNominalTypeCollector(context: context)
		collector.walk(sourceFile)
		nominalTypes += collector.nominalTypes
		let typeCollector = WorkspaceTypeDeclarationCollector(context: context)
		typeCollector.walk(sourceFile)
		typeDeclarations += typeCollector.declarations
		let collection = graphDiagramCollection(in: sourceFile)
		graphs += collection.diagrams.map { diagram in
			let id = WorkspaceDeclarationID(
				targetID: context.targetID,
				lexicalPath: diagram.lexicalName.split(separator: ".").map(String.init)
			)
			return WorkspaceGraphDescriptor(
				id: id,
				diagram: diagram,
				context: context,
				location: WorkspaceSourceLocation(
					targetID: context.targetID,
					path: context.path,
					utf8Offset: diagram.sourceOffset
				)
			)
		}
		excludedGraphs.formUnion(collection.excludedNames.map { name in
			WorkspaceDeclarationID(
				targetID: context.targetID,
				lexicalPath: name.split(separator: ".").map(String.init)
			)
		})
	}

	// 누적 선언을 결정적 순서의 색인으로 반환
	package func index() -> WorkspaceDeclarationIndex {
		WorkspaceDeclarationIndex(
			targets: targets,
			graphs: graphs,
			excludedGraphs: excludedGraphs,
			nominalTypes: nominalTypes,
			typeDeclarations: typeDeclarations
		)
	}
}

// class·actor·struct·enum의 member block과 graph input 표기를 수집하는 visitor
private final class WorkspaceTypeDeclarationCollector: SyntaxVisitor {
	// source context
	private let context: WorkspaceSourceContext
	// 현재 type 경로
	private var path = [String]()
	// 수집한 원본 type 선언
	private(set) var declarations = [WorkspaceTypeDeclaration]()

	init(context: WorkspaceSourceContext) {
		self.context = context
		super.init(viewMode: .sourceAccurate)
	}

	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
		appendDeclaration(name: node.name, attributes: node.attributes, kind: .classType, memberBlock: node.memberBlock)
		return .visitChildren
	}

	override func visitPost(_ node: ClassDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
		appendDeclaration(name: node.name, attributes: node.attributes, kind: .actor, memberBlock: node.memberBlock)
		return .visitChildren
	}

	override func visitPost(_ node: ActorDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
		appendDeclaration(name: node.name, attributes: node.attributes, kind: .struct, memberBlock: node.memberBlock)
		return .visitChildren
	}

	override func visitPost(_ node: StructDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
		appendDeclaration(name: node.name, attributes: node.attributes, kind: .enum, memberBlock: node.memberBlock)
		return .visitChildren
	}

	override func visitPost(_ node: EnumDeclSyntax) {
		path.removeLast()
	}

	private func appendDeclaration(
		name: TokenSyntax,
		attributes: AttributeListSyntax,
		kind: WorkspaceTypeDeclarationKind,
		memberBlock: MemberBlockSyntax
	) {
		path.append(workspaceIdentifierName(name))
		declarations.append(
			WorkspaceTypeDeclaration(
				id: WorkspaceDeclarationID(targetID: context.targetID, lexicalPath: path),
				context: context,
				kind: kind,
				memberBlock: memberBlock,
				graphInputTypeName: workspaceGraphInputTypeName(in: attributes)
			)
		)
	}
}

// @DependencyGraph(input: Input.self)의 input 타입 이름 반환
private func workspaceGraphInputTypeName(in attributes: AttributeListSyntax) -> String? {
	guard let attribute = attributes.compactMap({ $0.as(AttributeSyntax.self) }).first(where: { attribute in
		attribute.attributeName.trimmedDescription == "DependencyGraph"
			|| attribute.attributeName.trimmedDescription == "Cradle.DependencyGraph"
	}), case let .argumentList(arguments)? = attribute.arguments,
		let argument = arguments.first(where: { $0.label?.identifier?.name == "input" }),
		let member = argument.expression.as(MemberAccessExprSyntax.self),
		member.declName.baseName.text == "self",
		let base = member.base else {
		return nil
	}
	return base.trimmedDescription
}

// 명목 type의 lexical 경로와 직접 import를 수집하는 visitor
private final class WorkspaceNominalTypeCollector: SyntaxVisitor {
	// source context
	private let context: WorkspaceSourceContext
	// 현재 명목 type 경로
	private var path = [String]()
	// 수집한 명목 선언
	private(set) var nominalTypes = [WorkspaceNominalType]()

	init(context: WorkspaceSourceContext) {
		self.context = context
		super.init(viewMode: .sourceAccurate)
	}

	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
		appendNominalType(node.name)
		return .visitChildren
	}

	override func visitPost(_ node: ClassDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
		appendNominalType(node.name)
		return .visitChildren
	}

	override func visitPost(_ node: ActorDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
		appendNominalType(node.name)
		return .visitChildren
	}

	override func visitPost(_ node: StructDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
		appendNominalType(node.name)
		return .visitChildren
	}

	override func visitPost(_ node: EnumDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
		appendNominalType(node.name)
		return .visitChildren
	}

	override func visitPost(_ node: ProtocolDeclSyntax) {
		path.removeLast()
	}

	override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
		appendNominalType(node.name)
		path.removeLast()
		return .skipChildren
	}

	private func appendNominalType(_ name: TokenSyntax) {
		path.append(workspaceIdentifierName(name))
		nominalTypes.append(
			WorkspaceNominalType(
				id: WorkspaceDeclarationID(targetID: context.targetID, lexicalPath: path),
				context: context,
				location: WorkspaceSourceLocation(
					targetID: context.targetID,
					path: context.path,
					utf8Offset: graphSourceOffset(of: name)
				)
			)
		)
	}
}

// Swift identifier의 backtick 표기를 제거
private func workspaceIdentifierName(_ token: TokenSyntax) -> String {
	token.identifier?.name ?? token.text
}
