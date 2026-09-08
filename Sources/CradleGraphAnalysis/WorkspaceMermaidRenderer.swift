//
//  WorkspaceMermaidRenderer.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

// workspace 분석 결과를 module 묶음 Mermaid로 변환
// swiftlint:disable:next cyclomatic_complexity function_body_length
package func workspaceMermaidDiagram(for model: WorkspaceDiagramModel) -> String {
	let nodes = model.nodes.sorted { $0.key < $1.key }
	let nodeIDs = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
		(node.key, "workspaceNode\(index)")
	})
	var lines = [
		"%% CradleDiagramMaker가 생성한 workspace 의존성 graph",
		"%% 정적 분석 결과이며 런타임 실행 이력이나 객체 개수를 뜻하지 않음",
		"%% 모든 조건부 컴파일 절을 포함하며 실제 활성 build condition을 뜻하지 않음",
		"flowchart TB",
		"    classDef source stroke:#333,stroke-width:1px;",
		"    classDef shared stroke:#333,stroke-width:2px;",
		"    classDef lazy stroke:#333,stroke-width:2px,stroke-dasharray:2 3;",
		"    classDef transient stroke:#333,stroke-width:2px,stroke-dasharray:5 5;",
		"    classDef unknown stroke:#888,stroke-dasharray:4 4;"
	]
	for (index, target) in model.targets.enumerated() {
		let targetNodes = nodes.filter { $0.targetID == target.id }
		guard !targetNodes.isEmpty else {
			continue
		}
		lines.append("    subgraph workspaceModule\(index)[\"\(workspaceMermaidLabel(target.moduleName))\"]")
		let groups = Dictionary(grouping: targetNodes, by: { $0.graphKey ?? $0.key })
		for (groupIndex, key) in groups.keys.sorted().enumerated() {
			lines.append("        subgraph workspaceGraph\(index)_\(groupIndex)[\" \"]")
			for node in groups[key] ?? [] {
				guard let nodeID = nodeIDs[node.key] else { continue }
				lines.append("            \(nodeID)[\"\(workspaceMermaidLabel(node.label))\"]")
			}
			lines.append("        end")
		}
		lines.append("    end")
	}
	for edge in model.edges {
		guard let from = nodeIDs[edge.from], let destination = nodeIDs[edge.destination] else {
			continue
		}
		lines.append("    \(from) --> \(destination)")
	}
	for node in nodes {
		guard let nodeID = nodeIDs[node.key] else {
			continue
		}
		switch node.kind {
		case .graph, .externalSource, .input:
			lines.append("    class \(nodeID) source")
		case .provider:
			lines.append("    class \(nodeID) \(node.lifetime ?? "shared")")
		case .unknown:
			lines.append("    class \(nodeID) unknown")
		}
	}
	return lines.joined(separator: "\n") + "\n"
}

// Mermaid label에서 의미가 달라지는 문자 변환
private func workspaceMermaidLabel(_ value: String) -> String {
	value
		.replacingOccurrences(of: "&", with: "&amp;")
		.replacingOccurrences(of: "<", with: "&lt;")
		.replacingOccurrences(of: ">", with: "&gt;")
		.replacingOccurrences(of: "\"", with: "&quot;")
		.replacingOccurrences(of: "\n", with: "<br/>")
}
