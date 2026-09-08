//
//  DiagramMakerCommandTests.swift
//  CradleDiagramMakerSupportTests
//
//  Created by opfic on 9/8/26.
//

import CradleDiagramMakerSupport
import Foundation
import Testing

// 기존 target Mermaid 인자를 분석 요청으로 보존하는지 확인
@Test
func diagramMakerCommandParsesTargetRequest() throws {
	let command = try diagramMakerCommand(arguments: [
		"--module", "Example App", "--output", "/tmp/diagrams", "/tmp/App Graph.swift"
	])

	guard case let .target(request) = command else {
		Issue.record("target 요청 반환 필요")
		return
	}
	#expect(request.moduleName == "Example App")
	#expect(request.outputDirectoryURL == URL(fileURLWithPath: "/tmp/diagrams"))
	#expect(request.sourceURLs == [URL(fileURLWithPath: "/tmp/App Graph.swift")])
}

// 기존 target Mermaid 인자의 빈 source 목록을 허용하는지 확인
@Test
func diagramMakerCommandAcceptsTargetRequestWithoutSources() throws {
	let command = try diagramMakerCommand(arguments: ["--module", "App", "--output", "/tmp/diagrams"])

	guard case let .target(request) = command else {
		Issue.record("target 요청 반환 필요")
		return
	}
	#expect(request.sourceURLs.isEmpty)
}

// 알 수 없는 option을 기존 사용법 오류로 처리하는지 확인
@Test
func diagramMakerCommandRejectsUnknownOption() {
	#expect(throws: DiagramOutputError.self) {
		try diagramMakerCommand(arguments: [
			"--workspace", "workspace.json", "--output", "/tmp/diagrams", "--view", "unknown"
		])
	}
}

// workspace Mermaid 인자와 declarations 기본 보기를 변환하는지 확인
@Test
func diagramMakerCommandParsesWorkspaceRequest() throws {
	let command = try diagramMakerCommand(arguments: [
		"--workspace", "/tmp/workspace.json", "--output", "/tmp/diagrams"
	])

	guard case let .workspace(request) = command else {
		Issue.record("workspace 요청 반환 필요")
		return
	}
	#expect(request.manifestURL == URL(fileURLWithPath: "/tmp/workspace.json"))
	#expect(request.outputDirectoryURL == URL(fileURLWithPath: "/tmp/diagrams"))
	#expect(request.view == .declarations)
}
