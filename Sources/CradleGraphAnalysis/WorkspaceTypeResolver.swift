//
//  WorkspaceTypeResolver.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

// source graph 타입 표기를 workspace 선언으로 해석한 결과
package enum WorkspaceGraphResolution {
	// 활성 graph 선언 하나
	case graph(WorkspaceGraphDescriptor)
	// diagram: false 선언 하나
	case excluded(WorkspaceDeclarationID)
	// 후보가 없음
	case unresolved
	// 후보가 둘 이상
	case ambiguous
}

// lexical scope·직접 import·target dependency를 제한한 graph 이름 해석기
package struct WorkspaceTypeResolver {
	// 선언 조회 대상
	private let index: WorkspaceDeclarationIndex

	package init(index: WorkspaceDeclarationIndex) {
		self.index = index
	}

	// graph source의 정규 타입 철자를 실제 workspace graph로 해석
	package func resolve(source: GraphDiagramSource, in graph: WorkspaceGraphDescriptor) -> WorkspaceGraphResolution {
		let components = source.identity.canonicalText.split(separator: ".").map(String.init)
		guard !components.isEmpty else {
			return .unresolved
		}
		if components.count == 1 {
			return resolveUnqualified(components[0], in: graph)
		}
		var candidates = lexicalCandidates(components, in: graph)
		if lexicalPrefixExists(components[0], in: graph), candidates.isEmpty {
			return .unresolved
		}
		if let target = index.targets.first(where: { $0.moduleName == components[0] }),
			graph.context.moduleName == target.moduleName
				|| (graph.context.importedModules.contains(target.moduleName)
					&& graph.context.dependencyIDs.contains(target.id)) {
			candidates.append(WorkspaceDeclarationID(targetID: target.id, lexicalPath: Array(components.dropFirst())))
		}
		for target in index.targets where graph.context.importedModules.contains(target.moduleName)
			&& graph.context.dependencyIDs.contains(target.id) {
			candidates.append(WorkspaceDeclarationID(targetID: target.id, lexicalPath: components))
		}
		return resolveCandidates(candidates)
	}

	// 현재 lexical scope부터 바깥으로 무수식 graph 이름 탐색
	private func resolveUnqualified(_ name: String, in graph: WorkspaceGraphDescriptor) -> WorkspaceGraphResolution {
		var scope = Array(graph.id.lexicalPath.dropLast())
		while true {
			let candidate = WorkspaceDeclarationID(targetID: graph.context.targetID, lexicalPath: scope + [name])
			if nominalTypeExists(candidate) {
				return resolution(for: candidate)
			}
			guard !scope.isEmpty else {
				break
			}
			scope.removeLast()
		}
		let imported = index.targets.filter { target in
			graph.context.importedModules.contains(target.moduleName)
				&& graph.context.dependencyIDs.contains(target.id)
		}.map { WorkspaceDeclarationID(targetID: $0.id, lexicalPath: [name]) }
		return resolveCandidates(imported)
	}

	// active·excluded graph 후보를 정확한 declaration ID로 조회
	private func resolution(for id: WorkspaceDeclarationID) -> WorkspaceGraphResolution {
		let graphs = index.graphs.filter { $0.id == id }
		if graphs.count == 1, let graph = graphs.first {
			return .graph(graph)
		}
		if index.excludedGraphs.contains(id) {
			return .excluded(id)
		}
		return graphs.isEmpty ? .unresolved : .ambiguous
	}

	// 가까운 일반 nominal type의 이름 가림 확인
	private func nominalTypeExists(_ id: WorkspaceDeclarationID) -> Bool {
		index.nominalTypes.contains { $0.id == id } || index.excludedGraphs.contains(id)
	}

	private func lexicalCandidates(
		_ components: [String],
		in graph: WorkspaceGraphDescriptor
	) -> [WorkspaceDeclarationID] {
		var scope = Array(graph.id.lexicalPath.dropLast())
		while true {
			let prefix = WorkspaceDeclarationID(targetID: graph.context.targetID, lexicalPath: scope + [components[0]])
			if nominalTypeExists(prefix) {
				let candidate = WorkspaceDeclarationID(targetID: graph.context.targetID, lexicalPath: scope + components)
				return nominalTypeExists(candidate) ? [candidate] : []
			}
			guard !scope.isEmpty else { return [] }
			scope.removeLast()
		}
	}

	private func lexicalPrefixExists(_ name: String, in graph: WorkspaceGraphDescriptor) -> Bool {
		var scope = Array(graph.id.lexicalPath.dropLast())
		while true {
			if nominalTypeExists(WorkspaceDeclarationID(targetID: graph.context.targetID, lexicalPath: scope + [name])) {
				return true
			}
			guard !scope.isEmpty else { return false }
			scope.removeLast()
		}
	}

	private func resolveCandidates(_ candidates: [WorkspaceDeclarationID]) -> WorkspaceGraphResolution {
		let unique = Array(Set(candidates)).filter(nominalTypeExists).sorted()
		guard unique.count == 1, let candidate = unique.first else {
			return unique.isEmpty ? .unresolved : .ambiguous
		}
		return resolution(for: candidate)
	}
}
