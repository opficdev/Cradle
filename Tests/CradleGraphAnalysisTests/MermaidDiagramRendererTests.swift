//
//  MermaidDiagramRendererTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/4/26.
//

import Testing
@testable import CradleGraphAnalysis

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
	#expect(mermaidDiagram(for: forward) == mermaidDiagram(for: reverse))
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

	let mermaid = mermaidDiagram(for: diagram)

	#expect(mermaid.contains("provider0 --> provider1"))
	#expect(mermaid.contains("provider1 --> source0"))
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

	let mermaid = mermaidDiagram(for: diagram)

	#expect(mermaid.contains("provider0[\"Feature&lt;Protocol&gt;<br/>make&quot;Feature<br/>.shared\"]"))
	#expect(!mermaid.contains("provider-"))
}
