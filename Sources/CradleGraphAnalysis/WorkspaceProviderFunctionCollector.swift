//
//  WorkspaceProviderFunctionCollector.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

import SwiftSyntax

// graph 직접 member Factory 중 수집한 원본 위치와 일치하는 선언 수집기
final class WorkspaceProviderFunctionCollector: SyntaxVisitor {
	// 원본 provider 선언 정보
	private let provider: GraphDiagramProvider
	// 중첩 type·function 안쪽 선언 제외 깊이
	private var nestedDepth = 0
	// 일치한 직접 member Factory
	private(set) var function: FunctionDeclSyntax?

	init(provider: GraphDiagramProvider) {
		self.provider = provider
		super.init(viewMode: .sourceAccurate)
	}

	override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
		guard nestedDepth == 0, function == nil,
			(node.name.identifier?.name ?? node.name.text) == provider.factoryName,
			graphSourceOffset(of: node.name) == provider.sourceOffset else {
			return .skipChildren
		}
		function = node
		return .skipChildren
	}

	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	override func visitPost(_ node: ClassDeclSyntax) {
		nestedDepth -= 1
	}

	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	override func visitPost(_ node: ActorDeclSyntax) {
		nestedDepth -= 1
	}

	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	override func visitPost(_ node: StructDeclSyntax) {
		nestedDepth -= 1
	}

	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
		nestedDepth += 1
		return .visitChildren
	}

	override func visitPost(_ node: EnumDeclSyntax) {
		nestedDepth -= 1
	}

	override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
