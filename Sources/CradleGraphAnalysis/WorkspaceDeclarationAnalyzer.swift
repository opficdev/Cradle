//
//  WorkspaceDeclarationAnalyzer.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

// workspace 선언 관계를 renderer 모델로 변환하는 분석기
package struct WorkspaceDeclarationAnalyzer {
	// 선언 이름 해석기
	private let resolver: WorkspaceTypeResolver

	package init(index: WorkspaceDeclarationIndex) {
		resolver = WorkspaceTypeResolver(index: index)
	}

	// 선택 workspace의 선언 node·edge·진단 반환
	// swiftlint:disable:next function_body_length
	package func analyze(index: WorkspaceDeclarationIndex) -> WorkspaceDiagramModel {
		var nodes = [String: WorkspaceDiagramNode]()
		var edges = [WorkspaceEdgeKey: Set<WorkspaceSourceLocation>]()
		var diagnostics = Set<WorkspaceDiagramDiagnostic>()
		for graph in index.graphs {
			let graphKey = workspaceGraphKey(graph)
			nodes[graphKey] = WorkspaceDiagramNode(
				key: graphKey,
				kind: .graph,
				targetID: graph.id.targetID,
				label: "\(graph.context.moduleName).\(graph.id.lexicalName)",
				location: graph.location,
				graphKey: graphKey
			)
			let providers = graph.diagram.providers.sorted(by: workspaceProviderOrder)
			let providerKeys = providers.enumerated().map { index, provider in
				let key = workspaceProviderKey(graph, provider: provider, offset: index)
				nodes[key] = WorkspaceDiagramNode(
					key: key,
					kind: .provider,
					targetID: graph.id.targetID,
					label: "\(provider.typeName)<br/>\(provider.factoryName)<br/>.\(provider.lifetime.rawValue)",
					lifetime: provider.lifetime.rawValue,
					location: graph.location,
					graphKey: graphKey
				)
				return key
			}
			let providersByIdentity = Dictionary(grouping: providers.enumerated(), by: { $0.element.identity })
			let sourceKeys = sourceKeys(
				for: graph,
				nodes: &nodes,
				diagnostics: &diagnostics
			)
			for source in graph.diagram.sources {
				guard let sourceKey = sourceKeys[source.name] else {
					continue
				}
				workspaceInsertEdge(
					from: graphKey,
					to: sourceKey,
					kind: .sourceDeclaration,
					location: graph.location,
					into: &edges
				)
			}
			for (providerOffset, provider) in providers.enumerated() {
				let providerKey = providerKeys[providerOffset]
				for dependency in provider.dependencyIdentities {
					for candidate in providersByIdentity[dependency] ?? [] {
						workspaceInsertEdge(
							from: providerKey,
							to: providerKeys[candidate.offset],
							kind: .providerParameter,
							location: graph.location,
							into: &edges
						)
					}
				}
				for sourceName in provider.sourceNames {
					guard let sourceKey = sourceKeys[sourceName] else {
						continue
					}
					workspaceInsertEdge(
						from: providerKey,
						to: sourceKey,
						kind: .sourceRead,
						location: graph.location,
						into: &edges
					)
				}
			}
		}
		return WorkspaceDiagramModel(
			targets: index.targets,
			nodes: Array(nodes.values),
			edges: edges.map { key, evidence in
				WorkspaceDiagramEdge(from: key.from, to: key.destination, kind: key.kind, evidence: Array(evidence))
			},
			diagnostics: Array(diagnostics)
		)
	}

	// graph source마다 resolved anchor 또는 외부 node key 생성
	private func sourceKeys(
		for graph: WorkspaceGraphDescriptor,
		nodes: inout [String: WorkspaceDiagramNode],
		diagnostics: inout Set<WorkspaceDiagramDiagnostic>
	) -> [String: String] {
		var keys = [String: String]()
		for source in graph.diagram.sources {
			switch resolver.resolve(source: source, in: graph) {
			case let .graph(sourceGraph):
				keys[source.name] = workspaceGraphKey(sourceGraph)
			case .excluded:
				keys[source.name] = workspaceExternalSourceKey(graph, source: source)
				diagnostics.insert(workspaceDiagnostic(
					code: .excludedGraph,
					message: "`\(source.typeName)` source graph는 diagram: false로 제외되었습니다",
					graph: graph,
					source: source
				))
			case .unresolved:
				keys[source.name] = workspaceExternalSourceKey(graph, source: source)
				diagnostics.insert(workspaceDiagnostic(
					code: .unresolvedType,
					message: "`\(source.typeName)` source graph 선언을 해석할 수 없습니다",
					graph: graph,
					source: source
				))
			case .ambiguous:
				keys[source.name] = workspaceExternalSourceKey(graph, source: source)
				diagnostics.insert(workspaceDiagnostic(
					code: .ambiguousType,
					message: "`\(source.typeName)` source graph 후보가 여러 개입니다",
					graph: graph,
					source: source
				))
			}
			guard let key = keys[source.name], nodes[key] == nil else {
				continue
			}
			nodes[key] = WorkspaceDiagramNode(
				key: key,
				kind: .externalSource,
				targetID: graph.id.targetID,
				label: source.typeName,
				location: graph.location,
				graphKey: workspaceGraphKey(graph)
			)
		}
		return keys
	}
}

// edge 중복을 병합하기 위한 구조 key
private struct WorkspaceEdgeKey: Hashable {
	// 시작 node
	let from: String
	// 끝 node
	let destination: String
	// edge 종류
	let kind: WorkspaceDiagramEdgeKind
}

// provider의 결정적 출력 순서
private func workspaceProviderOrder(_ lhs: GraphDiagramProvider, _ rhs: GraphDiagramProvider) -> Bool {
	if lhs.identity.canonicalText != rhs.identity.canonicalText {
		return lhs.identity.canonicalText < rhs.identity.canonicalText
	}
	if lhs.factoryName != rhs.factoryName {
		return lhs.factoryName < rhs.factoryName
	}
	return lhs.typeName < rhs.typeName
}

// graph의 구조 key 생성
private func workspaceGraphKey(_ graph: WorkspaceGraphDescriptor) -> String {
	"graph/\(graph.id.targetID.rawValue)/\(graph.id.lexicalName)"
}

// provider의 구조 key 생성
private func workspaceProviderKey(
	_ graph: WorkspaceGraphDescriptor,
	provider: GraphDiagramProvider,
	offset: Int
) -> String {
	"provider/\(graph.id.targetID.rawValue)/\(graph.id.lexicalName)/\(provider.factoryName)/\(offset)"
}

// 해석할 수 없는 source의 graph별 node key 생성
private func workspaceExternalSourceKey(_ graph: WorkspaceGraphDescriptor, source: GraphDiagramSource) -> String {
	"source/\(graph.id.targetID.rawValue)/\(graph.id.lexicalName)/\(source.name)"
}

// edge와 근거 위치 병합
private func workspaceInsertEdge(
	from: String,
	to destination: String,
	kind: WorkspaceDiagramEdgeKind,
	location: WorkspaceSourceLocation,
	into edges: inout [WorkspaceEdgeKey: Set<WorkspaceSourceLocation>]
) {
	edges[WorkspaceEdgeKey(from: from, destination: destination, kind: kind), default: []].insert(location)
}

// source graph 해석 실패 진단 생성
private func workspaceDiagnostic(
	code: WorkspaceDiagnosticCode,
	message: String,
	graph: WorkspaceGraphDescriptor,
	source: GraphDiagramSource
) -> WorkspaceDiagramDiagnostic {
	WorkspaceDiagramDiagnostic(
		code: code,
		message: message,
		location: graph.location,
		context: WorkspaceDiagnosticContext(
			targetID: graph.id.targetID,
			declarationID: graph.id,
			memberName: source.name
		)
	)
}
