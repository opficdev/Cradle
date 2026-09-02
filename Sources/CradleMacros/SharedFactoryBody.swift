//
//  SharedFactoryBody.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax

// source 참조를 shared helper 매개변수로 치환하는 rewriter
private final class SourceGraphReferenceRewriter: SyntaxRewriter {
	// 탐색으로 수집한 source 참조
	private let references: SourceGraphReferences
	// source 저장 프로퍼티 이름과 helper 매개변수 이름 연결
	private let parameterNames: [String: String]

	init(references: SourceGraphReferences, parameterNames: [String: String]) {
		self.references = references
		self.parameterNames = parameterNames
	}

	// bare source 저장 프로퍼티를 helper 매개변수로 치환
	override func visit(_ node: DeclReferenceExprSyntax) -> ExprSyntax {
		let offset = sourceGraphOffset(of: node.baseName)
		guard let sourceName = references.bare[offset],
			let parameterName = parameterNames[sourceName] else {
			return super.visit(node)
		}
		return ExprSyntax(stringLiteral: parameterName)
	}

	// 명시적 self의 source 저장 프로퍼티를 helper 매개변수로 치환
	override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
		let offset = sourceGraphOffset(of: node.declName.baseName)
		guard let sourceName = references.explicitSelf[offset],
			let parameterName = parameterNames[sourceName] else {
			return super.visit(node)
		}
		return ExprSyntax(stringLiteral: parameterName)
	}

	// bare source closure capture에 helper 매개변수 initializer 추가
	override func visit(_ node: ClosureCaptureSyntax) -> ClosureCaptureSyntax {
		var rewritten = super.visit(node)
		guard node.initializer == nil,
			let sourceName = references.bareCapture[sourceGraphOffset(of: node.name)],
			let parameterName = parameterNames[sourceName] else {
			return rewritten
		}
		rewritten.initializer = InitializerClauseSyntax(value: ExprSyntax(stringLiteral: parameterName))
		return rewritten
	}
}

// source 참조를 helper 매개변수로 바꾼 Factory 본문 생성
func rewrittenSourceGraphFactoryBody(
	_ body: CodeBlockSyntax,
	references: SourceGraphReferences,
	parameterNames: [String: String]
) -> CodeBlockSyntax {
	guard !references.sourceNames.isEmpty else {
		return body
	}
	let rewriter = SourceGraphReferenceRewriter(
		references: references,
		parameterNames: parameterNames
	)
	return rewriter.rewrite(body, detach: true).as(CodeBlockSyntax.self)!
}
