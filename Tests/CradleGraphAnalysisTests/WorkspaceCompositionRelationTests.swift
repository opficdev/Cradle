//
//  WorkspaceCompositionRelationTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/8/26.
//

import SwiftParser
import Testing
@testable import CradleGraphAnalysis

// 임의 module·type 이름으로 생성과 기존 instance 보관의 차이 검증
@Test
func workspaceRelationsDistinguishCreationAndRetention() throws {
	let model = relationModel(source: relationSource)
	let container = try #require(model.nodes.first { $0.label == "Assembly.Container" })
	let nested = try #require(model.nodes.first { $0.label == "Assembly.Nested" })
	let returned = try #require(model.edges.first { $0.kind == .compositionReturn })
	#expect(returned.destination == container.key)
	#expect(model.nodes.first { $0.key == returned.from }?.label.contains("makeContainer") == true)
	let creations = model.edges.filter { $0.from == container.key && $0.kind == .compositionCreation }
	let retentions = model.edges.filter { $0.from == container.key && $0.kind == .compositionRetention }
	#expect(creations.count == 2)
	#expect(creations.contains { $0.destination == nested.key })
	#expect(retentions.count == 1)
	let retained = try #require(retentions.first)
	#expect(retained.evidence.count == 2)
	#expect(!creations.contains { $0.destination == retained.destination })
	#expect(model.nodes.first { $0.key == retained.destination }?.label == "Kernel.WorkerGraph")
	#expect(model.edges.contains { $0.from == nested.key && $0.kind == .compositionCreation })
	#expect(!model.nodes.contains { $0.label.contains("choose") })
	#expect(model.edges.allSatisfy { edge in
		model.nodes.contains { $0.key == edge.from } && model.nodes.contains { $0.key == edge.destination }
	})
	let bytes = Array(relationSource.utf8)
	for evidence in retained.evidence {
		#expect(evidence.path == "Assembly.swift")
		#expect(String(bytes: bytes.dropFirst(evidence.utf8Offset).prefix(8), encoding: .utf8) == "existing")
	}
	let position = try #require(returned.evidence.first)
	#expect(String(bytes: bytes.dropFirst(position.utf8Offset).prefix(9), encoding: .utf8) == "Container")
}

// 같은 type의 서로 다른 생성식과 중첩 인자 생성의 소유 관계 검증
@Test
func workspaceRelationsKeepDistinctInstances() {
	let model = relationModel(source: """
	import Kernel
	final class Container {
		let worker: WorkerGraph
		init(existing: WorkerGraph) { self.worker = existing }
	}
	final class Envelope {
		let first = Container(existing: WorkerGraph())
		let second = Container(existing: WorkerGraph())
	}
	@DependencyGraph final class Entry {
		@Provide func makeEnvelope() -> Envelope { Envelope() }
	}
	""", types: ["Container", "Envelope"])
	let containers = model.nodes.filter { $0.kind == .compositionObject && $0.label == "Assembly.Container" }
	let workers = model.nodes.filter { $0.label == "Kernel.WorkerGraph" }
	#expect(containers.count == 2 && workers.count == 2)
	let creations = model.edges.filter { $0.kind == .compositionCreation }
	#expect(creations.count == 2)
	#expect(creations.allSatisfy { edge in containers.contains { $0.key == edge.destination } })
	let retentions = model.edges.filter { $0.kind == .compositionRetention }
	#expect(retentions.count == 2)
	#expect(Set(retentions.map(\.destination)).count == 2)
}

// 일반 provider 값과 미지원 반환식에서 조립 관계를 추정하지 않는지 검증
@Test
func workspaceRelationsDoNotExpandUnknownValues() {
	let model = relationModel(source: """
	final class Container { let worker = unknownFactory() }
	@DependencyGraph final class Entry {
		@Provide func makeToken() -> Token { Token() }
		@Provide func makeContainer() -> Container { unknownFactory() }
	}
	""", types: ["Container"])
	#expect(!model.nodes.contains { $0.kind == .compositionObject })
	#expect(!model.edges.contains { relationKinds.contains($0.kind) })
	#expect(!model.diagnostics.isEmpty)
}

// initializer 직접 생성과 Factory 지역 별칭 반환의 위치 검증
@Test
func workspaceRelationsRecordInitializerCreationAndReturnAlias() throws {
	let source = """
	import Kernel
	final class Container {
		let worker: WorkerGraph
		init() { self.worker = WorkerGraph() }
	}
	@DependencyGraph final class Entry {
		@Provide func makeContainer() -> Container {
			let value = Container()
			return value
		}
	}
	"""
	let model = relationModel(source: source, types: ["Container"])
	#expect(model.edges.filter { $0.kind == .compositionCreation }.count == 1)
	#expect(!model.edges.contains { $0.kind == .compositionRetention })
	let returned = try #require(model.edges.first { $0.kind == .compositionReturn })
	let evidence = try #require(returned.evidence.first)
	#expect(String(bytes: source.utf8.dropFirst(evidence.utf8Offset).prefix(5), encoding: .utf8) == "value")
}

// source 수집 순서와 무관한 관계·위치·Mermaid 출력 검증
@Test
func workspaceRelationsRemainDeterministic() {
	let first = relationModel(source: relationSource)
	let second = relationModel(source: relationSource, reversed: true)
	#expect(first.nodes == second.nodes)
	#expect(first.edges == second.edges)
	#expect(first.diagnostics == second.diagnostics)
	#expect(workspaceMermaidDiagram(for: first) == workspaceMermaidDiagram(for: second))
}

// 버려진 생성식에 반환 관계를 붙이지 않는지 검증
@Test
func workspaceRelationsDoNotLabelDiscardedExpressionsAsReturn() {
	let model = relationModel(source: """
	final class Container {}
	@DependencyGraph final class Entry {
		@Provide func makeContainer() -> Container {
			Container()
			return Container()
		}
	}
	""", types: ["Container"])
	#expect(!model.edges.contains { $0.kind == .compositionReturn })
}

// 새 관계 종류만 점선으로 출력하고 DI는 실선으로 유지하는지 검증
@Test
func workspaceRelationsRenderDistinctEdgeKinds() {
	let model = relationModel(source: relationSource)
	let diagram = workspaceMermaidDiagram(for: model)
	#expect(diagram.contains("-. 반환 .->"))
	#expect(diagram.contains("-. 생성 .->"))
	#expect(diagram.contains("-. 보관 .->"))
	#expect(diagram.contains("compositionObject"))
	#expect(diagram.contains("실선: 값 의존 관계"))
	#expect(diagram.contains(" --> "))
	#expect(model.edges.filter { $0.kind == .providerParameter }.count == 3)
}

// 비교할 조립 간선 종류
private let relationKinds: Set<WorkspaceDiagramEdgeKind> = [
	.compositionReturn, .compositionCreation, .compositionRetention
]

// 보관 별칭·중첩 객체·부분 미해석을 포함한 일반 조립 입력
private let relationSource = """
import Kernel
final class Nested { let worker = WorkerGraph() }
final class Container {
	let built = (WorkerGraph())
	let unknown = choose()
	let nested = Nested()
	let left: WorkerGraph
	let right: WorkerGraph
	init(existing: WorkerGraph) {
		self.left = existing
		self.right = existing
	}
}
@DependencyGraph final class Entry {
	@Provide func makeContainer() -> Container {
		let graph = WorkerGraph()
		let alias = graph
		return Container(existing: alias)
	}
}
"""

// module 이름과 root·조립 타입을 명시한 독립 분석 모델 생성
private func relationModel(
	source: String,
	types: [String] = ["Container", "Nested"],
	reversed: Bool = false
) -> WorkspaceDiagramModel {
	let kernel = WorkspaceTargetID("Kernel")
	let assembly = WorkspaceTargetID("Assembly")
	let targets = [
		WorkspaceTargetDescriptor(id: kernel, moduleName: "Kernel", dependencyIDs: []),
		WorkspaceTargetDescriptor(id: assembly, moduleName: "Assembly", dependencyIDs: [kernel])
	]
	let collector = WorkspaceDeclarationCollector(targets: reversed ? targets.reversed() : targets)
	let inputs = [("Kernel", """
	@DependencyGraph final class WorkerGraph {
		@Provide func makeToken() -> Token { Token() }
		@Provide func makeValue(token: Token) -> Value { Value(token) }
	}
	"""), ("Assembly", source)]
	for (module, text) in reversed ? inputs.reversed() : inputs {
		collector.collect(sourceFile: Parser.parse(source: text), context: WorkspaceSourceContext(
			targetID: WorkspaceTargetID(module), moduleName: module, path: "\(module).swift",
			dependencyIDs: module == "Assembly" ? [kernel] : [],
			importedModules: module == "Assembly" ? ["Kernel"] : []
		))
	}
	return WorkspaceCompositionAnalyzer(
		index: collector.index(),
		roots: [WorkspaceDeclarationID(targetID: assembly, lexicalPath: ["Entry"])],
		compositionTypes: Set(types.map { WorkspaceDeclarationID(targetID: assembly, lexicalPath: [$0]) })
	).analyze()
}
