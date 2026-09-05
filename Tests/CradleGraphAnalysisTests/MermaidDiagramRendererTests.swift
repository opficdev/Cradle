//
//  MermaidDiagramRendererTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/4/26.
//

import Foundation
import Testing
import SwiftParser
@testable import CradleGraphAnalysis

// 조건부 절의 동일 경로에 활성 graph가 있으면 그 anchor를 사용하는지 검증
@Test
func targetGraphDiagramRetainsEnabledConditionalDeclaration() throws {
	let collection = graphDiagramCollection(in: Parser.parse(source: """
	#if DEBUG
	@DependencyGraph final class SharedGraph {}
	#else
	@DependencyGraph(diagram: false) final class SharedGraph {}
	#endif
	@DependencyGraph(sources: [SharedGraph.self]) final class AppGraph {}
	"""))
	let graph = try #require(collection.diagrams.first { $0.lexicalName == "AppGraph" })
	let source = try #require(graph.sources.first)
	let target = TargetGraphDiagram(diagrams: collection.diagrams, excludedNames: collection.excludedNames)
	#expect(target.anchor(for: source, in: graph) == "graph1_root")
}

// 공유·순환 source와 사용하지 않은 source도 같은 graph anchor에 연결하는지 검증
@Test
func mermaidDiagramUnifiesSharedAndCyclicGraphs() {
	let diagrams = graphDiagrams(in: Parser.parse(source: """
	@DependencyGraph(sources: [BGraph.self, CGraph.self])
	final class AGraph {
		@Provide func makeFeature() -> Feature { Feature(bGraph.value) }
	}
	@DependencyGraph(sources: [CGraph.self]) final class BGraph {}
	@DependencyGraph(sources: [AGraph.self]) final class CGraph {}
	"""))
	let mermaid = mermaidDiagram(for: diagrams)
	#expect(mermaid.contains("flowchart TB"))
	#expect(mermaid.components(separatedBy: "    subgraph ").count - 1 == 3)
	#expect(mermaid.contains("graph0_root --> graph1_root"))
	#expect(mermaid.contains("graph0_root --> graph2_root"))
	#expect(mermaid.contains("graph1_root --> graph2_root"))
	#expect(mermaid.contains("graph2_root --> graph0_root"))
	#expect(mermaid.contains("graph0_provider0 --> graph1_root"))
	#expect(mermaid.contains("subgraph graph0[\" \"]"))
	#expect(!mermaid.contains("subgraph graph0[\"AGraph\"]"))
	#expect(mermaid.components(separatedBy: "AGraph").count - 1 == 1)
	#expect(!mermaid.contains("_source"))
	#expect(mermaidDiagram(for: diagrams.reversed()) == mermaid)
}

// 동명 provider는 graph 안에서만 연결하고 외부·제외 source의 내부는 숨기는지 검증
@Test
func mermaidDiagramIsolatesProvidersAndExcludedGraphs() {
	let diagrams = graphDiagrams(in: Parser.parse(source: """
	@DependencyGraph(sources: [HiddenGraph.self, External.Graph.self])
	final class AGraph {
		@Provide func makeFeature(value: Value) -> Feature { Feature(value) }
		@Provide func makeValue() -> Value { Value() }
	}
	@DependencyGraph final class BGraph {
		@Provide func makeFeature(value: Value) -> Feature { Feature(value) }
		@Provide func makeValue() -> Value { Value() }
	}
	@DependencyGraph(diagram: false) final class HiddenGraph {
		@Provide func makeSecret() -> Secret { Secret() }
	}
	"""))
	let mermaid = mermaidDiagram(for: diagrams)
	#expect(mermaid.contains("graph0_provider0 --> graph0_provider1"))
	#expect(mermaid.contains("graph1_provider0 --> graph1_provider1"))
	#expect(!mermaid.contains("graph0_provider0 --> graph1_provider1"))
	#expect(mermaid.contains("graph0_root --> graph0_source0"))
	#expect(mermaid.contains("graph0_root --> graph0_source1"))
	#expect(mermaid.contains("HiddenGraph") && mermaid.contains("External.Graph"))
	#expect(!mermaid.contains("Secret"))
	#expect(mermaid.components(separatedBy: "    subgraph ").count - 1 == 2)
}

// 가장 가까운 lexical scope와 명시적 경로만 연결하고 suffix 추측을 하지 않는지 검증
@Test
func targetGraphDiagramResolvesExactLexicalSources() throws {
	let diagrams = graphDiagrams(in: Parser.parse(source: """
	@DependencyGraph final class SharedGraph {}
	enum Parent {
		@DependencyGraph final class SharedGraph {}
		enum Child {
			@DependencyGraph(sources: [SharedGraph.self, Parent.SharedGraph.self,
				Foreign.SharedGraph.self, MissingGraph.self, App.SharedGraph.self])
			final class AppGraph {}
		}
	}
	enum Other { @DependencyGraph final class MissingGraph {} }
	"""))
	let target = TargetGraphDiagram(diagrams: diagrams)
	let graph = try #require(diagrams.first { $0.lexicalName == "Parent.Child.AppGraph" })
	let resolved = Dictionary(uniqueKeysWithValues: graph.sources.map {
		($0.typeName, target.anchor(for: $0, in: graph))
	})
	#expect(resolved["SharedGraph"] == "graph2_root")
	#expect(resolved["Parent.SharedGraph"] == "graph2_root")
	#expect(resolved["Foreign.SharedGraph"]! == nil)
	#expect(resolved["MissingGraph"]! == nil)
	#expect(resolved["App.SharedGraph"]! == nil)
}

// 조건부 동명 Factory의 수명·의존성·source 차이에도 선언 순서 독립성 보존
@Test
func mermaidDiagramOrdersConditionalProviderVariants() {
	let variants = [
		GraphDiagramProvider(factoryName: "make", typeName: "Feature",
			identity: GraphTypeIdentity(canonicalText: "Feature"), lifetime: .shared,
			dependencyIdentities: [], sourceNames: ["first"]),
		GraphDiagramProvider(factoryName: "make", typeName: "Feature",
			identity: GraphTypeIdentity(canonicalText: "Feature"), lifetime: .transient,
			dependencyIdentities: [], sourceNames: ["first"]),
		GraphDiagramProvider(factoryName: "make", typeName: "Feature",
			identity: GraphTypeIdentity(canonicalText: "Feature"), lifetime: .shared,
			dependencyIdentities: [], sourceNames: ["second"]),
		GraphDiagramProvider(factoryName: "make", typeName: "Feature",
			identity: GraphTypeIdentity(canonicalText: "Feature"), lifetime: .shared,
			dependencyIdentities: [GraphTypeIdentity(canonicalText: "Feature")], sourceNames: [])
	]
	let sources = ["first", "second"].map {
		GraphDiagramSource(name: $0, typeName: $0, identity: GraphTypeIdentity(canonicalText: $0))
	}
	let forward = GraphDiagram(lexicalName: "AppGraph", sourceOffset: 0, sources: sources, providers: variants)
	let reverse = GraphDiagram(lexicalName: "AppGraph", sourceOffset: 0,
		sources: sources.reversed(), providers: variants.reversed())
	#expect(mermaidDiagram(for: [forward]) == mermaidDiagram(for: [reverse]))
}

// 관계와 node 수명 표현을 Mermaid 코드로 변환하는지 확인
@Test
func mermaidDiagramRendersSolidRelationshipsAndLifetimeBorders() {
	let diagram = GraphDiagram(
		lexicalName: "AppGraph",
		sourceOffset: 0,
		sources: [
			GraphDiagramSource(
				name: "sessionGraph",
				typeName: "SessionGraph",
				identity: GraphTypeIdentity(canonicalText: "SessionGraph")
			)
		],
		providers: [
			GraphDiagramProvider(
				factoryName: "makeRepository",
				typeName: "Repository",
				identity: GraphTypeIdentity(canonicalText: "Repository"),
				lifetime: .shared,
				dependencyIdentities: [],
				sourceNames: ["sessionGraph"]
			),
			GraphDiagramProvider(
				factoryName: "makeFeature",
				typeName: "Feature",
				identity: GraphTypeIdentity(canonicalText: "Feature"),
				lifetime: .transient,
				dependencyIdentities: [GraphTypeIdentity(canonicalText: "Repository")],
				sourceNames: []
			)
		]
	)

	let mermaid = mermaidDiagram(for: [diagram])

	#expect(mermaid.contains("graph0_provider0 --> graph0_provider1"))
	#expect(mermaid.contains("graph0_provider1 --> graph0_source0"))
	#expect(mermaid.contains("classDef shared stroke:#333,stroke-width:2px;"))
	#expect(mermaid.contains("classDef transient stroke:#333,stroke-width:2px,stroke-dasharray:5 5;"))
	#expect(!mermaid.contains("-.->"))
}

// Mermaid node ID가 사람이 읽는 label에 의존하지 않는지 확인
@Test
func mermaidDiagramEscapesLabelsWithoutChangingNodeIDs() {
	let diagram = GraphDiagram(
		lexicalName: "Feature<Graph>",
		sourceOffset: 0,
		sources: [],
		providers: [
			GraphDiagramProvider(
				factoryName: "make\"Feature",
				typeName: "Feature<Protocol>",
				identity: GraphTypeIdentity(canonicalText: "FeatureProtocol"),
				lifetime: .shared,
				dependencyIdentities: [],
				sourceNames: []
			)
		]
	)

	let mermaid = mermaidDiagram(for: [diagram])

	#expect(mermaid.contains("graph0_provider0[\"Feature&lt;Protocol&gt;<br/>make&quot;Feature<br/>.shared\"]"))
	#expect(!mermaid.contains("provider-"))
}
