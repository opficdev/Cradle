//
//  WorkspaceDiagramModel.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

// workspace Mermaid의 node 종류
package enum WorkspaceDiagramNodeKind: String, Codable {
	// DependencyGraph 선언 anchor
	case graph
	// @Provide Factory
	case provider
	// graph initializer input의 저장 멤버
	case input
	// 분석할 수 없는 source graph
	case externalSource
	// 분석 한계로 출처를 알 수 없는 값
	case unknown
}

// workspace Mermaid의 관계 종류
package enum WorkspaceDiagramEdgeKind: String, Codable {
	// graph sources 선언
	case sourceDeclaration
	// 같은 graph의 provider 매개변수
	case providerParameter
	// Factory가 source graph accessor를 읽은 관계
	case sourceRead
	// Factory가 graph input 멤버를 읽은 관계
	case inputRead
	// graph input에 실제 provider 값을 전달한 관계
	case inputBinding
}

// workspace 분석 진단 심각도
package enum WorkspaceDiagnosticSeverity: String, Codable {
	// 분석 결과를 보존할 수 있는 경고
	case warning
}

// workspace 분석 진단 코드
package enum WorkspaceDiagnosticCode: String, Codable {
	// source graph 선언을 해석하지 못한 경우
	case unresolvedType
	// source graph 후보가 여러 개인 경우
	case ambiguousType
	// diagram: false graph를 참조한 경우
	case excludedGraph
	// 지원하지 않는 expression을 만난 경우
	case unsupportedExpression
	// 지원하지 않는 제어 흐름을 만난 경우
	case unsupportedControlFlow
	// 지원하지 않는 저장 멤버를 만난 경우
	case unsupportedMember
	// input 전체를 특정 멤버로 좁힐 수 없는 경우
	case opaqueInputUse
	// initializer 후보가 여러 개인 경우
	case ambiguousInitializer
	// provider 후보가 여러 개인 경우
	case ambiguousProvider
	// provider·object 평가가 순환한 경우
	case cyclicEvaluation
	// 정한 분석 한도를 넘은 경우
	case analysisLimit
}

// workspace 분석 진단의 graph·멤버 문맥
package struct WorkspaceDiagnosticContext: Hashable, Codable {
	// 진단이 발생한 target
	package let targetID: WorkspaceTargetID
	// 관련 graph 선언
	package let declarationID: WorkspaceDeclarationID?
	// 관련 source accessor 이름
	package let memberName: String?

	package init(
		targetID: WorkspaceTargetID,
		declarationID: WorkspaceDeclarationID? = nil,
		memberName: String? = nil
	) {
		self.targetID = targetID
		self.declarationID = declarationID
		self.memberName = memberName
	}
}

// workspace Mermaid 결과에 포함할 분석 진단
package struct WorkspaceDiagramDiagnostic: Hashable, Codable {
	// 진단 종류
	package let code: WorkspaceDiagnosticCode
	// 사람이 읽는 실패 원인
	package let message: String
	// 근거 source 위치
	package let location: WorkspaceSourceLocation?
	// 진단 발생 문맥
	package let context: WorkspaceDiagnosticContext
	// 현재는 부분 분석 경고만 생성
	package let severity: WorkspaceDiagnosticSeverity

	package init(
		code: WorkspaceDiagnosticCode,
		message: String,
		location: WorkspaceSourceLocation?,
		context: WorkspaceDiagnosticContext,
		severity: WorkspaceDiagnosticSeverity = .warning
	) {
		self.code = code
		self.message = message
		self.location = location
		self.context = context
		self.severity = severity
	}
}

// workspace Mermaid node의 구조·표시 정보
package struct WorkspaceDiagramNode: Hashable, Codable {
	// 출력 순서를 고정할 의미 key
	package let key: String
	// node 역할
	package let kind: WorkspaceDiagramNodeKind
	// node가 속한 target
	package let targetID: WorkspaceTargetID
	// 사람이 읽는 Mermaid label
	package let label: String
	// provider lifetime class
	package let lifetime: String?
	// 선언 근거 위치
	package let location: WorkspaceSourceLocation?
	// node가 속한 graph node key
	package let graphKey: String?

	package init(
		key: String,
		kind: WorkspaceDiagramNodeKind,
		targetID: WorkspaceTargetID,
		label: String,
		lifetime: String? = nil,
		location: WorkspaceSourceLocation? = nil,
		graphKey: String? = nil
	) {
		self.key = key
		self.kind = kind
		self.targetID = targetID
		self.label = label
		self.lifetime = lifetime
		self.location = location
		self.graphKey = graphKey
	}
}

// workspace Mermaid edge와 source 근거
package struct WorkspaceDiagramEdge: Hashable, Codable {
	// 의존하는 node key
	package let from: String
	// 의존 대상 node key
	package let destination: String
	// 관계 역할
	package let kind: WorkspaceDiagramEdgeKind
	// source 위치 근거
	package let evidence: [WorkspaceSourceLocation]

	package init(
		from: String,
		to destination: String,
		kind: WorkspaceDiagramEdgeKind,
		evidence: [WorkspaceSourceLocation]
	) {
		self.from = from
		self.destination = destination
		self.kind = kind
		self.evidence = evidence.sorted()
	}
}

// renderer와 report가 공유하는 결정적 workspace 분석 결과
package struct WorkspaceDiagramModel {
	// 선택한 target과 실제 module 이름
	package let targets: [WorkspaceTargetDescriptor]
	// 출력할 node
	package let nodes: [WorkspaceDiagramNode]
	// 출력할 edge
	package let edges: [WorkspaceDiagramEdge]
	// 부분 분석 진단
	package let diagnostics: [WorkspaceDiagramDiagnostic]

	package init(
		targets: [WorkspaceTargetDescriptor],
		nodes: [WorkspaceDiagramNode],
		edges: [WorkspaceDiagramEdge],
		diagnostics: [WorkspaceDiagramDiagnostic]
	) {
		self.targets = targets.sorted { $0.id < $1.id }
		self.nodes = nodes.sorted { $0.key < $1.key }
		self.edges = edges.sorted { lhs, rhs in
			if lhs.from != rhs.from {
				return lhs.from < rhs.from
			}
			if lhs.destination != rhs.destination {
				return lhs.destination < rhs.destination
			}
			return lhs.kind.rawValue < rhs.kind.rawValue
		}
		self.diagnostics = diagnostics.sorted { lhs, rhs in
			if lhs.code != rhs.code {
				return lhs.code.rawValue < rhs.code.rawValue
			}
			if lhs.context.targetID != rhs.context.targetID {
				return lhs.context.targetID < rhs.context.targetID
			}
		let leftLocation = lhs.location
			?? WorkspaceSourceLocation(targetID: lhs.context.targetID, path: "", utf8Offset: 0)
		let rightLocation = rhs.location
			?? WorkspaceSourceLocation(targetID: rhs.context.targetID, path: "", utf8Offset: 0)
			if leftLocation != rightLocation { return leftLocation < rightLocation }
			let leftDeclaration = lhs.context.declarationID.map(String.init(describing:)) ?? ""
			let rightDeclaration = rhs.context.declarationID.map(String.init(describing:)) ?? ""
			if leftDeclaration != rightDeclaration { return leftDeclaration < rightDeclaration }
			let leftMember = lhs.context.memberName ?? ""
			let rightMember = rhs.context.memberName ?? ""
			if leftMember != rightMember { return leftMember < rightMember }
			return lhs.message < rhs.message
		}
	}
}
