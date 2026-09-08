//
//  WorkspaceDiagramManifestTests.swift
//  CradleDiagramMakerSupportTests
//
//  Created by opfic on 9/8/26.
//

import CradleDiagramMakerSupport
import Foundation
import Testing

// 유효한 workspace manifest 계약을 해독하고 검증하는지 확인
@Test
func workspaceDiagramManifestValidatesTargetsAndRoots() throws {
	let manifest = try workspaceManifest(from: """
	{
		"schemaVersion": 1,
		"workspaceName": "App",
		"rootDirectory": ".",
		"targets": [
			{"id":"Domain","moduleName":"Domain","sourceFiles":["Domain.swift"],"dependencies":[]},
			{"id":"App","moduleName":"App","sourceFiles":["App.swift"],"dependencies":["Domain"]}
		],
		"roots": [{"targetID":"App","graph":"AppGraph"}],
		"compositionTypes": [{"targetID":"App","type":"AppGraphSet"}]
	}
	""")

	try manifest.validate()
	#expect(manifest.targets.map(\.id) == ["Domain", "App"])
}

// 알 수 없는 JSON key를 조용히 무시하지 않는지 확인
@Test
func workspaceDiagramManifestRejectsUnknownKey() {
	#expect(throws: WorkspaceDiagramManifestError.self) {
		let manifest = try workspaceManifest(from: """
		{"schemaVersion":1,"workspaceName":"App","rootDirectory":".","targets":[{"id":"App","moduleName":"App","sourceFiles":["App.swift"],"unexpected":true}]}
		""")
		try manifest.validate()
	}
}

// 존재하지 않는 dependency를 계약 오류로 처리하는지 확인
@Test
func workspaceDiagramManifestRejectsUnknownDependency() {
	#expect(throws: WorkspaceDiagramManifestError.self) {
		let manifest = try workspaceManifest(from: """
		{"schemaVersion":1,"workspaceName":"App","rootDirectory":".","targets":[{"id":"App","moduleName":"App","sourceFiles":["App.swift"],"dependencies":["Missing"]}]}
		""")
		try manifest.validate()
	}
}

// 순환 dependency를 계약 오류로 처리하는지 확인
@Test
func workspaceDiagramManifestRejectsCyclicDependencies() {
	#expect(throws: WorkspaceDiagramManifestError.self) {
		let manifest = try workspaceManifest(from: """
		{"schemaVersion":1,"workspaceName":"App","rootDirectory":".","targets":[{"id":"A","moduleName":"A","sourceFiles":["A.swift"],"dependencies":["B"]},{"id":"B","moduleName":"B","sourceFiles":["B.swift"],"dependencies":["A"]}]}
		""")
		try manifest.validate()
	}
}

// 여러 module source를 declarations Mermaid와 report로 저장하는지 확인
@Test
func workspaceDiagramOutputWriterWritesDeclarations() throws {
	let temporary = try makeWorkspaceDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let domain = temporary.appendingPathComponent("Domain.swift")
	let app = temporary.appendingPathComponent("App.swift")
	let manifest = temporary.appendingPathComponent("workspace.json")
	try "@DependencyGraph public final class DataGraph {}"
		.write(to: domain, atomically: true, encoding: .utf8)
	try """
	import Domain
	@DependencyGraph(sources: [Domain.DataGraph.self])
	public final class AppGraph {}
	""".write(to: app, atomically: true, encoding: .utf8)
	try """
	{
		"schemaVersion": 1,
		"workspaceName": "ExampleWorkspace",
		"rootDirectory": ".",
		"targets": [
			{"id":"Domain","moduleName":"Domain","sourceFiles":["Domain.swift"],"dependencies":[]},
			{"id":"App","moduleName":"App","sourceFiles":["App.swift"],"dependencies":["Domain"]}
		]
	}
	""".write(to: manifest, atomically: true, encoding: .utf8)

	let outputs = try WorkspaceDiagramOutputWriter().write(
		request: WorkspaceDiagramRequest(
			manifestURL: manifest,
			outputDirectoryURL: temporary.appendingPathComponent("output"),
			view: .declarations
		)
	)

	#expect(outputs.map(\.lastPathComponent) == ["Declarations.mmd", "Declarations.analysis.json"])
	let mermaid = try String(contentsOf: outputs[0], encoding: .utf8)
	let report = try String(contentsOf: outputs[1], encoding: .utf8)
	#expect(mermaid.contains("App.AppGraph") && mermaid.contains("Domain.DataGraph"))
	#expect(report.contains("\"view\" : \"declarations\""))
}

// root graph의 일반 조립 객체와 Graph(input:)을 composition 산출물로 연결하는지 확인
@Test
// swiftlint:disable:next function_body_length
func workspaceDiagramOutputWriterWritesComposition() throws {
	let temporary = try makeWorkspaceDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let domain = temporary.appendingPathComponent("Domain.swift")
	let app = temporary.appendingPathComponent("App.swift")
	let manifest = temporary.appendingPathComponent("workspace.json")
	try """
	struct DomainInput {
		let service: Service
		init(from provider: Service) { self.service = provider }
	}
	@DependencyGraph(input: DomainInput.self) final class DomainGraph {
		@Provide func makeRepository() -> Repository { Repository(service: input.service) }
	}
	""".write(to: domain, atomically: true, encoding: .utf8)
	try """
	import Domain
	final class AppGraphSet {
		let domainGraph: DomainGraph
		init(service: Service) {
			self.domainGraph = DomainGraph(input: DomainInput(from: service))
		}
	}
	@DependencyGraph final class AppGraph {
		@Provide func makeService() -> Service { Service() }
		@Provide func makeGraphSet(service: Service) -> AppGraphSet { AppGraphSet(service: service) }
	}
	""".write(to: app, atomically: true, encoding: .utf8)
	try """
	{
		"schemaVersion": 1,
		"workspaceName": "ExampleWorkspace",
		"rootDirectory": ".",
		"targets": [
			{"id":"Domain","moduleName":"Domain","sourceFiles":["Domain.swift"],"dependencies":[]},
			{"id":"App","moduleName":"App","sourceFiles":["App.swift"],"dependencies":["Domain"]}
		],
		"roots": [{"targetID":"App","graph":"AppGraph"}],
		"compositionTypes": [{"targetID":"App","type":"AppGraphSet"}]
	}
	""".write(to: manifest, atomically: true, encoding: .utf8)

	let outputs = try WorkspaceDiagramOutputWriter().write(
		request: WorkspaceDiagramRequest(
			manifestURL: manifest,
			outputDirectoryURL: temporary.appendingPathComponent("output"),
			view: .composition
		)
	)

	#expect(outputs.map(\.lastPathComponent) == ["Composition.mmd", "Composition.analysis.json"])
	let mermaid = try String(contentsOf: outputs[0], encoding: .utf8)
	let report = try String(contentsOf: outputs[1], encoding: .utf8)
	#expect(mermaid.contains("input.service"))
	#expect(report.contains("\"view\" : \"composition\""))
	#expect(report.contains("makeService") && report.contains("makeRepository"))
	let json = try #require(JSONSerialization.jsonObject(with: Data(report.utf8)) as? [String: Any])
	#expect(json["schemaVersion"] as? Int == 2)
	let edges = try #require(json["edges"] as? [[String: Any]])
	#expect(edges.contains { $0["kind"] as? String == "compositionReturn" })
	#expect(edges.contains { $0["kind"] as? String == "compositionCreation" })
	let nodes = try #require(json["nodes"] as? [[String: Any]])
	#expect(nodes.contains { $0["kind"] as? String == "compositionObject" })
}

// JSON 문자열을 manifest DTO로 해독
private func workspaceManifest(from string: String) throws -> WorkspaceDiagramManifest {
	try JSONDecoder().decode(WorkspaceDiagramManifest.self, from: Data(string.utf8))
}

// workspace writer test용 임시 디렉터리 생성
private func makeWorkspaceDiagramTemporaryDirectory() throws -> URL {
	let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	return directory
}
