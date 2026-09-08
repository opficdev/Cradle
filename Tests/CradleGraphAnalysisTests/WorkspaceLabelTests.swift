//
//  WorkspaceLabelTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/8/26.
//

import SwiftParser
import Testing
@testable import CradleGraphAnalysis

// 두 workspace 보기의 개행과 타입 문자의 이스케이프 유지 검증
@Test
func workspaceProviderLabelsPreserveLineBreaks() {
	let target = WorkspaceTargetID("App")
	let collector = WorkspaceDeclarationCollector(targets: [
		WorkspaceTargetDescriptor(id: target, moduleName: "App", dependencyIDs: [])
	])
	collector.collect(sourceFile: Parser.parse(source: """
	@DependencyGraph final class AppGraph {
		@Provide func makeValues() -> Array<String> { [] }
	}
	"""), context: WorkspaceSourceContext(
		targetID: target, moduleName: "App", path: "App.swift",
		dependencyIDs: [], importedModules: []
	))
	let index = collector.index()
	let models = [
		WorkspaceDeclarationAnalyzer(index: index).analyze(index: index),
		WorkspaceCompositionAnalyzer(
			index: index,
			roots: [WorkspaceDeclarationID(targetID: target, lexicalPath: ["AppGraph"])],
			compositionTypes: []
		).analyze()
	]
	for model in models {
		#expect(model.nodes.contains { $0.label == "Array<String>\nmakeValues\n.shared" })
		let diagram = workspaceMermaidDiagram(for: model)
		#expect(diagram.contains("Array&lt;String&gt;<br/>makeValues<br/>.shared"))
		#expect(!diagram.contains("&lt;br/&gt;"))
	}
}
