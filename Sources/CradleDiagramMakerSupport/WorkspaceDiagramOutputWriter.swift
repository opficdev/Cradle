//
//  WorkspaceDiagramOutputWriter.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/8/26.
//

import CradleGraphAnalysis
import Foundation

// workspace 분석 결과를 Mermaid와 JSON으로 저장하는 writer
package struct WorkspaceDiagramOutputWriter {
	package init() {}

	// 요청 view에 대응하는 tool 소유 산출물 반환
	@discardableResult
	// swiftlint:disable:next function_body_length
	package func write(request: WorkspaceDiagramRequest) throws -> [URL] {
		let loaded = try WorkspaceDiagramLoader().load(request: request)
		let model: WorkspaceDiagramModel
		switch request.view {
		case .declarations:
			model = WorkspaceDeclarationAnalyzer(index: loaded.index).analyze(index: loaded.index)
		case .composition:
			let roots = loaded.manifest.roots.map { root in
				WorkspaceDeclarationID(
					targetID: WorkspaceTargetID(root.targetID),
					lexicalPath: root.graph.split(separator: ".").map(String.init)
				)
			}
			let rootGraphs = roots.compactMap { root in
				loaded.index.graphs.first { $0.id == root }
			}
			guard rootGraphs.count == roots.count,
				rootGraphs.allSatisfy({ graph in
					graph.diagram.sources.isEmpty
						&& loaded.index.typeDeclaration(for: graph.id)?.graphInputTypeName == nil
				}) else {
				throw WorkspaceDiagramOutputError.invalidRoot
			}
			let compositionTypes = Set(loaded.manifest.compositionTypes.map { type in
				WorkspaceDeclarationID(
					targetID: WorkspaceTargetID(type.targetID),
					lexicalPath: type.type.split(separator: ".").map(String.init)
				)
			})
			model = WorkspaceCompositionAnalyzer(
				index: loaded.index,
				roots: roots,
				compositionTypes: compositionTypes
			).analyze()
		}
		let mermaid = workspaceMermaidDiagram(for: model)
		let report = try workspaceDiagramReportData(view: request.view, model: model)
		let directory = request.outputDirectoryURL.appendingPathComponent(loaded.manifest.workspaceName)
		let outputs = workspaceOutputURLs(in: directory, view: request.view)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		guard !model.nodes.isEmpty else {
			for output in outputs where FileManager.default.fileExists(atPath: output.path) {
				try FileManager.default.removeItem(at: output)
			}
			return []
		}
		try writeIfChanged(Data(mermaid.utf8), to: outputs[0])
		try writeIfChanged(report, to: outputs[1])
		for diagnostic in model.diagnostics {
			let location = diagnostic.location.map { "\($0.path):\($0.utf8Offset): " } ?? ""
			FileHandle.standardError.write(Data("workspace Mermaid 경고: \(location)\(diagnostic.message)\n".utf8))
		}
		return outputs
	}

	// view별 Mermaid와 report 파일 경로 반환
	private func workspaceOutputURLs(in directory: URL, view: WorkspaceDiagramView) -> [URL] {
		switch view {
		case .declarations:
			return [
				directory.appendingPathComponent("Declarations.mmd"),
				directory.appendingPathComponent("Declarations.analysis.json")
			]
		case .composition:
			return [
				directory.appendingPathComponent("Composition.mmd"),
				directory.appendingPathComponent("Composition.analysis.json")
			]
		}
	}

	// 내용이 달라질 때만 원자적 파일 교체
	private func writeIfChanged(_ data: Data, to url: URL) throws {
		if let existing = try? Data(contentsOf: url), existing == data {
			return
		}
		try data.write(to: url, options: .atomic)
	}
}

// workspace 산출물 생성 중단 사유
package enum WorkspaceDiagramOutputError: LocalizedError {
	case invalidRoot

	package var errorDescription: String? {
		switch self {
		case .invalidRoot:
			return "workspace Mermaid composition root는 input과 sources가 없는 graph여야 합니다"
		}
	}
}
