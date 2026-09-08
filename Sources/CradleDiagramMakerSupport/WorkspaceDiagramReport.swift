//
//  WorkspaceDiagramReport.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/8/26.
//

import CradleGraphAnalysis
import Foundation

// workspace Mermaid와 함께 저장할 구조화 분석 결과
private struct WorkspaceDiagramReport: Encodable {
	// report 형식 버전
	let schemaVersion = 2
	// 생성한 보기 이름
	let view: WorkspaceDiagramView
	// 선택 target과 실제 module 이름
	let targets: [WorkspaceDiagramReportTarget]
	// 분석 node
	let nodes: [WorkspaceDiagramNode]
	// 분석 edge
	let edges: [WorkspaceDiagramEdge]
	// 부분 분석 진단
	let diagnostics: [WorkspaceDiagramDiagnostic]

	init(view: WorkspaceDiagramView, model: WorkspaceDiagramModel) {
		self.view = view
		targets = model.targets.map { target in
			WorkspaceDiagramReportTarget(id: target.id.rawValue, moduleName: target.moduleName)
		}
		nodes = model.nodes
		edges = model.edges
		diagnostics = model.diagnostics
	}
}

// report target의 공개 JSON 표현
private struct WorkspaceDiagramReportTarget: Encodable {
	// manifest target 식별자
	let id: String
	// 실제 Swift module 이름
	let moduleName: String
}

// 결정적 JSON Data 생성
func workspaceDiagramReportData(view: WorkspaceDiagramView, model: WorkspaceDiagramModel) throws -> Data {
	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
	return try encoder.encode(WorkspaceDiagramReport(view: view, model: model))
}
