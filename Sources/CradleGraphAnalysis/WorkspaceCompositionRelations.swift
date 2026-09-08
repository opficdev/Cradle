//
//  WorkspaceCompositionRelations.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

import SwiftSyntax

// 이미 평가된 조립 결과의 표시 정보 기록
extension WorkspaceCompositionAnalyzer {
	// 추가 평가 없이 실제 객체 또는 graph의 기존 key 조회
	private func compositionKey(for value: WorkspaceCompositionValue) -> String? {
		switch value {
		case let .object(object): return object.key
		case let .graph(graph): return graph.key
		case .provider, .input, .unknown: return nil
		}
	}

	// 일반 객체를 선언 module 안에 독립 instance로 표시
	func recordCompositionObject(_ object: WorkspaceCompositionObject) {
		let declaration = object.declaration
		let location = index.nominalTypes.first { $0.id == declaration.id }?.location
		nodes[object.key] = WorkspaceDiagramNode(
			key: object.key,
			kind: .compositionObject,
			targetID: declaration.id.targetID,
			label: "\(declaration.context.moduleName).\(declaration.id.lexicalName)",
			location: location,
			graphKey: object.key
		)
	}

	// 반환식에서 확정된 객체로 Factory 반환 관계 기록
	func recordCompositionReturn(
		_ value: WorkspaceCompositionValue,
		from providerKey: String,
		expression: ExprSyntax,
		context: WorkspaceSourceContext
	) {
		guard let destination = compositionKey(for: value) else { return }
		insertEdge(
			from: providerKey, to: destination, kind: .compositionReturn,
			location: compositionLocation(expression, context: context)
		)
	}

	// 저장 우변의 직접 생성과 기존 참조 보관을 구분해 기록
	func recordCompositionStorage(
		_ value: WorkspaceCompositionValue,
		in object: WorkspaceCompositionObject,
		expression: ExprSyntax
	) {
		guard let destination = compositionKey(for: value) else { return }
		var unwrapped = expression
		while let tuple = unwrapped.as(TupleExprSyntax.self), tuple.elements.count == 1,
			let element = tuple.elements.first, element.label == nil {
			unwrapped = element.expression
		}
		let kind: WorkspaceDiagramEdgeKind
		if unwrapped.is(FunctionCallExprSyntax.self) {
			kind = .compositionCreation
		} else if unwrapped.is(DeclReferenceExprSyntax.self) || unwrapped.is(MemberAccessExprSyntax.self) {
			kind = .compositionRetention
		} else {
			return
		}
		insertEdge(
			from: object.key, to: destination, kind: kind,
			location: compositionLocation(expression, context: object.declaration.context)
		)
	}
}

// 평가 전 source 문맥과 원본 expression에 대응하는 위치
private func compositionLocation(_ expression: ExprSyntax, context: WorkspaceSourceContext) -> WorkspaceSourceLocation {
	WorkspaceSourceLocation(
		targetID: context.targetID,
		path: context.path,
		utf8Offset: expression.positionAfterSkippingLeadingTrivia.utf8Offset
	)
}
