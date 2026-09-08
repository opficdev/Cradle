//
//  DiagramMakerCommand.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/8/26.
//

import Foundation

// CradleDiagramMaker의 분석 요청 종류
package enum DiagramMakerCommand {
	// 기존 target source 기반 Mermaid 생성 요청
	case target(DiagramOutputRequest)
	// 여러 target의 workspace Mermaid 생성 요청
	case workspace(WorkspaceDiagramRequest)
}

// 명령행 인자를 분석 요청으로 변환
package func diagramMakerCommand(arguments: [String]) throws -> DiagramMakerCommand {
	if arguments.first == "--workspace" {
		return try workspaceDiagramMakerCommand(arguments: arguments)
	}
	guard 4 <= arguments.count,
		arguments[0] == "--module",
		arguments[2] == "--output",
		arguments[4...].allSatisfy({ !$0.hasPrefix("--") }) else {
		throw DiagramOutputError.invalidArguments
	}
	return .target(
		DiagramOutputRequest(
			moduleName: arguments[1],
			sourceURLs: arguments.dropFirst(4).map { URL(fileURLWithPath: $0) },
			outputDirectoryURL: URL(fileURLWithPath: arguments[3])
		)
	)
}

// workspace 전용 명령행 인자를 분석 요청으로 변환
private func workspaceDiagramMakerCommand(arguments: [String]) throws -> DiagramMakerCommand {
	guard 4 <= arguments.count,
		arguments[0] == "--workspace",
		arguments[2] == "--output" else {
		throw DiagramOutputError.invalidArguments
	}
	let remaining = Array(arguments.dropFirst(4))
	let view: WorkspaceDiagramView
	if remaining.isEmpty {
		view = .declarations
	} else if remaining.count == 2,
		remaining[0] == "--view",
		let parsed = WorkspaceDiagramView(rawValue: remaining[1]) {
		view = parsed
	} else {
		throw DiagramOutputError.invalidArguments
	}
	return .workspace(
		WorkspaceDiagramRequest(
			manifestURL: URL(fileURLWithPath: arguments[1]),
			outputDirectoryURL: URL(fileURLWithPath: arguments[3]),
			view: view
		)
	)
}
