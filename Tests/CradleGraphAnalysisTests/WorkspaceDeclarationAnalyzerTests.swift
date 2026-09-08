//
//  WorkspaceDeclarationAnalyzerTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/8/26.
//

import SwiftParser
import Testing
@testable import CradleGraphAnalysis

// source fixture의 선언을 보존하기 위한 긴 입력 허용
// swiftlint:disable line_length

// 직접 import한 다른 module graph source를 선언 edge로 연결하는지 확인
@Test
func workspaceDeclarationAnalyzerConnectsImportedSourceGraph() {
	let domain = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("Domain"),
		moduleName: "Domain",
		dependencyIDs: []
	)
	let app = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("App"),
		moduleName: "App",
		dependencyIDs: [WorkspaceTargetID("Domain")]
	)
	let collector = WorkspaceDeclarationCollector(targets: [domain, app])
	collector.collect(
		sourceFile: Parser.parse(source: "@DependencyGraph final class DataGraph {}"),
		context: workspaceContext(targetID: "Domain", moduleName: "Domain", path: "Domain.swift")
	)
	collector.collect(
		sourceFile: Parser.parse(source: """
		import Domain
		@DependencyGraph(sources: [Domain.DataGraph.self])
		final class AppGraph {
			@Provide func makeFeature() -> Feature { Feature(dataGraph: dataGraph) }
		}
		"""),
		context: workspaceContext(
			targetID: "App",
			moduleName: "App",
			path: "App.swift",
			dependencies: ["Domain"],
			imports: ["Domain"]
		)
	)

	let model = WorkspaceDeclarationAnalyzer(index: collector.index()).analyze(index: collector.index())

	#expect(model.edges.contains {
		$0.kind == .sourceDeclaration
			&& $0.from == "graph/App/AppGraph"
			&& $0.destination == "graph/Domain/DataGraph"
	})
	#expect(workspaceMermaidDiagram(for: model).contains("subgraph workspaceModule0[\"App\"]"))
	#expect(workspaceMermaidDiagram(for: model).contains("subgraph workspaceModule1[\"Domain\"]"))
}

// 직접 import하지 않은 graph 후보를 추측 연결하지 않는지 확인
@Test
func workspaceDeclarationAnalyzerLeavesUnimportedSourceExternal() {
	let domain = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("Domain"),
		moduleName: "Domain",
		dependencyIDs: []
	)
	let app = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("App"),
		moduleName: "App",
		dependencyIDs: [WorkspaceTargetID("Domain")]
	)
	let collector = WorkspaceDeclarationCollector(targets: [domain, app])
	collector.collect(
		sourceFile: Parser.parse(source: "@DependencyGraph final class DataGraph {}"),
		context: workspaceContext(targetID: "Domain", moduleName: "Domain", path: "Domain.swift")
	)
	collector.collect(
		sourceFile: Parser.parse(source: "@DependencyGraph(sources: [DataGraph.self]) final class AppGraph {}"),
		context: workspaceContext(targetID: "App", moduleName: "App", path: "App.swift", dependencies: ["Domain"])
	)

	let model = WorkspaceDeclarationAnalyzer(index: collector.index()).analyze(index: collector.index())

	#expect(!model.edges.contains { $0.destination == "graph/Domain/DataGraph" })
	#expect(model.diagnostics.map(\.code) == [.unresolvedType])
}

// 제외 graph와 활성 graph가 같은 이름이면 활성 graph로 추측 연결하지 않는지 확인
@Test
func workspaceDeclarationAnalyzerDoesNotChooseActiveGraphBehindExcludedCandidate() {
	let collector = WorkspaceDeclarationCollector(targets: [
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("A"), moduleName: "A", dependencyIDs: []),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("B"), moduleName: "B", dependencyIDs: []),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: [WorkspaceTargetID("A"), WorkspaceTargetID("B")])
	])
	collector.collect(sourceFile: Parser.parse(source: "@DependencyGraph(diagram: false) final class SharedGraph {}"), context: workspaceContext(targetID: "A", moduleName: "A", path: "A.swift"))
	collector.collect(sourceFile: Parser.parse(source: "@DependencyGraph final class SharedGraph {}"), context: workspaceContext(targetID: "B", moduleName: "B", path: "B.swift"))
	collector.collect(sourceFile: Parser.parse(source: "@DependencyGraph(sources: [SharedGraph.self]) final class AppGraph {}"), context: workspaceContext(targetID: "App", moduleName: "App", path: "App.swift", dependencies: ["A", "B"], imports: ["A", "B"]))

	let model = WorkspaceDeclarationAnalyzer(index: collector.index()).analyze(index: collector.index())
	#expect(!model.edges.contains { $0.destination == "graph/B/SharedGraph" })
	#expect(model.diagnostics.map(\.code) == [.ambiguousType])
}

// typealias가 module 접두사와 겹치면 외부 module graph로 연결하지 않는지 확인
@Test
func workspaceDeclarationAnalyzerHonorsTypeAliasModulePrefixShadowing() {
	let collector = WorkspaceDeclarationCollector(targets: [
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("Domain"), moduleName: "Domain", dependencyIDs: []),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: [WorkspaceTargetID("Domain")])
	])
	collector.collect(sourceFile: Parser.parse(source: "@DependencyGraph final class SharedGraph {}"), context: workspaceContext(targetID: "Domain", moduleName: "Domain", path: "Domain.swift"))
	collector.collect(sourceFile: Parser.parse(source: """
	import Domain
	typealias Domain = LocalNamespace
	@DependencyGraph(sources: [Domain.SharedGraph.self]) final class AppGraph {}
	"""), context: workspaceContext(targetID: "App", moduleName: "App", path: "App.swift", dependencies: ["Domain"], imports: ["Domain"]))

	let model = WorkspaceDeclarationAnalyzer(index: collector.index()).analyze(index: collector.index())
	#expect(!model.edges.contains { $0.destination == "graph/Domain/SharedGraph" })
	#expect(model.diagnostics.map(\.code) == [.unresolvedType])
}

// 가까운 scope의 typealias가 바깥 완성 graph 경로보다 먼저 이름을 가리는지 확인
@Test
func workspaceDeclarationAnalyzerStopsAtNearestQualifiedPrefixShadowing() {
	let collector = WorkspaceDeclarationCollector(targets: [
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: [])
	])
	collector.collect(sourceFile: Parser.parse(source: """
	enum Scope { @DependencyGraph final class Graph {} }
	enum Outer {
		typealias Scope = OtherNamespace
		@DependencyGraph(sources: [Scope.Graph.self]) final class AppGraph {}
	}
	"""), context: workspaceContext(targetID: "App", moduleName: "App", path: "App.swift"))

	let model = WorkspaceDeclarationAnalyzer(index: collector.index()).analyze(index: collector.index())
	#expect(!model.edges.contains { $0.destination == "graph/App/Scope.Graph" })
	#expect(model.diagnostics.map(\.code) == [.unresolvedType])
}

// 직접 import한 외부 module의 중첩 graph를 해석하는지 확인
@Test
func workspaceDeclarationAnalyzerConnectsImportedNestedGraph() {
	let collector = WorkspaceDeclarationCollector(targets: [
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("Domain"), moduleName: "Domain", dependencyIDs: []),
		WorkspaceTargetDescriptor(id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: [WorkspaceTargetID("Domain")])
	])
	collector.collect(sourceFile: Parser.parse(source: "enum Scope { @DependencyGraph final class SharedGraph {} }"), context: workspaceContext(targetID: "Domain", moduleName: "Domain", path: "Domain.swift"))
	collector.collect(sourceFile: Parser.parse(source: "import Domain\n@DependencyGraph(sources: [Scope.SharedGraph.self]) final class AppGraph {}"), context: workspaceContext(targetID: "App", moduleName: "App", path: "App.swift", dependencies: ["Domain"], imports: ["Domain"]))

	let model = WorkspaceDeclarationAnalyzer(index: collector.index()).analyze(index: collector.index())
	#expect(model.edges.contains { $0.destination == "graph/Domain/Scope.SharedGraph" })
}

// extension 안쪽 graph와 원본 type 선언의 lexical 경로를 동일하게 보존하는지 검증
@Test
func workspaceDeclarationCollectorKeepsExtensionTypePaths() {
	let target = WorkspaceTargetDescriptor(
		id: WorkspaceTargetID("App"), moduleName: "App", dependencyIDs: []
	)
	let collector = WorkspaceDeclarationCollector(targets: [target])
	collector.collect(sourceFile: Parser.parse(source: """
	enum Scope {}
	extension Scope {
		@DependencyGraph final class Graph {}
	}
	@DependencyGraph final class Graph {}
	"""), context: workspaceContext(targetID: "App", moduleName: "App", path: "App.swift"))

	let index = collector.index()
	let scoped = WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["Scope", "Graph"])
	let topLevel = WorkspaceDeclarationID(targetID: WorkspaceTargetID("App"), lexicalPath: ["Graph"])

	#expect(Set(index.graphs.map(\.id)) == [scoped, topLevel])
	#expect(index.typeDeclaration(for: scoped)?.id == scoped)
	#expect(index.nominalTypes.contains { $0.id == scoped })
	#expect(index.typeDeclaration(for: topLevel)?.id == topLevel)
	#expect(index.nominalTypes.contains { $0.id == topLevel })
}

// workspace source context 생성
private func workspaceContext(
	targetID: String,
	moduleName: String,
	path: String,
	dependencies: Set<String> = [],
	imports: Set<String> = []
) -> WorkspaceSourceContext {
	WorkspaceSourceContext(
		targetID: WorkspaceTargetID(targetID),
		moduleName: moduleName,
		path: path,
		dependencyIDs: Set(dependencies.map(WorkspaceTargetID.init)),
		importedModules: imports
	)
}

// swiftlint:enable line_length
