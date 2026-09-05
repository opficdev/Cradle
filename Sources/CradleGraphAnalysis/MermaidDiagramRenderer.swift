//
//  MermaidDiagramRenderer.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/4/26.
//

import Foundation

// 정적 graph 모델을 Mermaid flowchart 코드로 변환
package func mermaidDiagram(for diagram: GraphDiagram) -> String {
	let sources = diagram.sources.sorted(by: graphDiagramSourceOrder)
	let providers = diagram.providers.sorted(by: graphDiagramProviderOrder)
	let sourceIDs = Dictionary(uniqueKeysWithValues: sources.indices.map { index in
		(sources[index].name, "source\(index)")
	})
	let providerIDs = providers.indices.map { "provider\($0)" }
	let providersByIdentity = Dictionary(grouping: providers.enumerated(), by: { _, provider in
		provider.identity
	})

	var lines = [
		"%% CradlePlugin이 생성한 의존성 graph",
		"%% 모든 조건부 컴파일 절을 포함하며 실제 활성 build condition을 뜻하지 않음",
		"%% plugin work directory 산출물이므로 swift package clean 뒤 사라질 수 있음",
		"flowchart LR",
		"    subgraph graph[\"\(mermaidLabel(diagram.lexicalName))\"]"
	]
	lines += sources.enumerated().map { index, source in
		"        source\(index)[\"\(mermaidLabel(source.typeName))\"]"
	}
	lines += providers.enumerated().map { index, provider in
		"        provider\(index)[\"\(mermaidProviderLabel(provider))\"]"
	}
	lines.append("    end")
	lines += mermaidEdges(
		providers: providers,
		providerIDs: providerIDs,
		providersByIdentity: providersByIdentity,
		sourceIDs: sourceIDs
	)
	lines += mermaidNodeStyles(
		sources: sources,
		providers: providers,
		sourceIDs: sourceIDs,
		providerIDs: providerIDs
	)
	return lines.joined(separator: "\n") + "\n"
}

// source graph의 안정적인 Mermaid node 순서
private func graphDiagramSourceOrder(_ lhs: GraphDiagramSource, _ rhs: GraphDiagramSource) -> Bool {
	if lhs.identity.canonicalText != rhs.identity.canonicalText {
		return lhs.identity.canonicalText < rhs.identity.canonicalText
	}
	if lhs.name != rhs.name {
		return lhs.name < rhs.name
	}
	return lhs.typeName < rhs.typeName
}

// provider의 안정적인 Mermaid node 순서
private func graphDiagramProviderOrder(_ lhs: GraphDiagramProvider, _ rhs: GraphDiagramProvider) -> Bool {
	if lhs.identity.canonicalText != rhs.identity.canonicalText {
		return lhs.identity.canonicalText < rhs.identity.canonicalText
	}
	if lhs.factoryName != rhs.factoryName {
		return lhs.factoryName < rhs.factoryName
	}
	if lhs.typeName != rhs.typeName {
		return lhs.typeName < rhs.typeName
	}
	if lhs.lifetime != rhs.lifetime {
		return lhs.lifetime.rawValue < rhs.lifetime.rawValue
	}
	// 간선에 사용되는 집합을 정렬해 조건부 동명 Factory의 순서 고정
	let leftDependencies = Set(lhs.dependencyIdentities.map(\.canonicalText)).sorted()
	let rightDependencies = Set(rhs.dependencyIdentities.map(\.canonicalText)).sorted()
	if leftDependencies != rightDependencies {
		return leftDependencies.lexicographicallyPrecedes(rightDependencies)
	}
	return lhs.sourceNames.sorted().lexicographicallyPrecedes(rhs.sourceNames.sorted())
}

// provider의 type 의존성과 source 참조를 모두 실선 화살표로 반환
private func mermaidEdges(
	providers: [GraphDiagramProvider],
	providerIDs: [String],
	providersByIdentity: [GraphTypeIdentity: [(offset: Int, element: GraphDiagramProvider)]],
	sourceIDs: [String: String]
) -> [String] {
	var edges = Set<String>()
	for (index, provider) in providers.enumerated() {
		for identity in provider.dependencyIdentities {
			for dependency in providersByIdentity[identity] ?? [] {
				edges.insert("    \(providerIDs[index]) --> \(providerIDs[dependency.offset])")
			}
		}
		for sourceName in provider.sourceNames.sorted() {
			guard let sourceID = sourceIDs[sourceName] else {
				continue
			}
			edges.insert("    \(providerIDs[index]) --> \(sourceID)")
		}
	}
	return edges.sorted()
}

// lifetime과 source graph 경계를 Mermaid class로 구분
private func mermaidNodeStyles(
	sources: [GraphDiagramSource],
	providers: [GraphDiagramProvider],
	sourceIDs: [String: String],
	providerIDs: [String]
) -> [String] {
	var lines = [
		"    classDef source stroke:#333,stroke-width:1px;",
		"    classDef shared stroke:#333,stroke-width:2px;",
		"    classDef transient stroke:#333,stroke-width:2px,stroke-dasharray:5 5;"
	]
	for source in sources {
		guard let sourceID = sourceIDs[source.name] else {
			continue
		}
		lines.append("    class \(sourceID) source")
	}
	for (index, provider) in providers.enumerated() {
		lines.append("    class \(providerIDs[index]) \(provider.lifetime.rawValue)")
	}
	return lines
}

// provider node에서 Factory와 수명을 함께 표시
private func mermaidProviderLabel(_ provider: GraphDiagramProvider) -> String {
	let lifetime = ".\(provider.lifetime.rawValue)"
	return [provider.typeName, provider.factoryName, lifetime]
		.map(mermaidLabel)
		.joined(separator: "<br/>")
}

// Mermaid 대괄호 label에서 의미가 달라지는 문자를 이스케이프
private func mermaidLabel(_ value: String) -> String {
	value
		.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "<", with: "&lt;")
		.replacingOccurrences(of: ">", with: "&gt;")
		.replacingOccurrences(of: "\"", with: "&quot;")
}
