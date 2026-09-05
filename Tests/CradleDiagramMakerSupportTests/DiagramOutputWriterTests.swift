//
//  DiagramOutputWriterTests.swift
//  CradleDiagramMakerSupportTests
//
//  Created by opfic on 9/4/26.
//

import CradleDiagramMakerSupport
import Foundation
import Testing

// 제외 graph가 가까운 범위에 있으면 바깥 동명 graph로 연결하지 않는지 검증
@Test
func diagramOutputWriterPreservesExcludedLexicalShadowing() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("Graphs.swift")
	try """
	@DependencyGraph final class SharedGraph {}
	enum Scope {
		@DependencyGraph(diagram: false) final class SharedGraph {
			@Provide func makeSecret() -> Secret { Secret() }
		}
		@DependencyGraph(sources: [SharedGraph.self]) final class AppGraph {}
	}
	""".write(to: source, atomically: true, encoding: .utf8)
	let outputs = try DiagramOutputWriter().write(request: DiagramOutputRequest(
		moduleName: "App", sourceURLs: [source], outputDirectoryURL: temporary))
	let output = try #require(outputs.first)
	let content = try String(contentsOf: output, encoding: .utf8)
	#expect(content.contains("graph0_root --> graph0_source0"))
	#expect(!content.contains("graph0_root --> graph1_root"))
	#expect(!content.contains("Secret"))
}

// 여러 source 파일을 하나로 합치고 이전 graph별 산출물만 정리하는지 검증
@Test
func diagramOutputWriterCombinesTargetAndMigratesOldFiles() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let first = temporary.appendingPathComponent("First.swift")
	let second = temporary.appendingPathComponent("Second.swift")
	try "@DependencyGraph(sources: [BGraph.self]) final class AGraph {}"
		.write(to: first, atomically: true, encoding: .utf8)
	try "@DependencyGraph final class BGraph {}".write(to: second, atomically: true, encoding: .utf8)
	let directory = temporary.appendingPathComponent("App")
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	let old = directory.appendingPathComponent("AGraph-old.mmd")
	let note = directory.appendingPathComponent("note.txt")
	try "old".write(to: old, atomically: true, encoding: .utf8)
	try "keep".write(to: note, atomically: true, encoding: .utf8)
	let writer = DiagramOutputWriter()
	let outputs = try writer.write(request: DiagramOutputRequest(
		moduleName: "App", sourceURLs: [first, second], outputDirectoryURL: temporary))
	#expect(outputs == [directory.appendingPathComponent("DependencyGraph.mmd")])
	let output = try #require(outputs.first)
	let content = try String(contentsOf: output, encoding: .utf8)
	#expect(content.contains("AGraph") && content.contains("BGraph"))
	#expect(content.contains("graph0_root --> graph1_root"))
	#expect(!FileManager.default.fileExists(atPath: old.path))
	#expect(try String(contentsOf: note, encoding: .utf8) == "keep")
	let date = Date(timeIntervalSinceReferenceDate: 1)
	try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: output.path)
	try writer.write(request: DiagramOutputRequest(
		moduleName: "App", sourceURLs: [second, first], outputDirectoryURL: temporary))
	#expect(try String(contentsOf: output, encoding: .utf8) == content)
	#expect(try FileManager.default.attributesOfItem(atPath: output.path)[.modificationDate] as? Date == date)
	// 모든 graph를 제외하면 단일 산출물도 제거
	try "@DependencyGraph(diagram: false) final class AGraph {}"
		.write(to: first, atomically: true, encoding: .utf8)
	try "@DependencyGraph(diagram: false) final class BGraph {}"
		.write(to: second, atomically: true, encoding: .utf8)
	#expect(try writer.write(request: DiagramOutputRequest(
		moduleName: "App", sourceURLs: [first, second], outputDirectoryURL: temporary)).isEmpty)
	#expect(!FileManager.default.fileExists(atPath: output.path))
}

// 변경된 graph만 쓰고 이전 content의 수정 시각을 보존하는지 확인
@Test
func diagramOutputWriterWritesStableOutputWithoutRewritingUnchangedContent() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	try """
	@DependencyGraph
	final class AppGraph {
		@Provide
		private func makeFeature() -> Feature { Feature() }
	}
	""".write(to: source, atomically: true, encoding: .utf8)
	let request = DiagramOutputRequest(
		moduleName: "AppComposition",
		sourceURLs: [source],
		outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
	)

	let outputs = try DiagramOutputWriter().write(request: request)
	#expect(outputs.count == 1)
	let output = try #require(outputs.first)
	let originalDate = Date(timeIntervalSinceReferenceDate: 1)
	try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: output.path)
	let repeated = try DiagramOutputWriter().write(request: request)
	let modificationDate = try #require(
		FileManager.default.attributesOfItem(atPath: output.path)[.modificationDate] as? Date
	)

	#expect(repeated == [output])
	#expect(modificationDate == originalDate)
	#expect(output.pathExtension == "mmd")
}

// 제외되거나 삭제된 graph의 tool 소유 산출물을 정리하는지 확인
@Test
func diagramOutputWriterRemovesStaleModuleOutput() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	try "@DependencyGraph(diagram: false) final class AppGraph {}"
		.write(to: source, atomically: true, encoding: .utf8)
	let outputDirectory = temporary.appendingPathComponent("CradleDiagrams/AppComposition")
	try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
	let stale = outputDirectory.appendingPathComponent("AppGraph-old.mmd")
	try "stale".write(to: stale, atomically: true, encoding: .utf8)

	let outputs = try DiagramOutputWriter().write(
		request: DiagramOutputRequest(
			moduleName: "AppComposition",
			sourceURLs: [source],
			outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
		)
	)

	#expect(outputs.isEmpty)
	#expect(!FileManager.default.fileExists(atPath: stale.path))
}

// 중복 lexical graph 오류가 기존 성공 산출물을 유지하는지 확인
@Test
func diagramOutputWriterPreservesExistingOutputWhenConditionalGraphsCollide() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	let outputDirectory = temporary.appendingPathComponent("CradleDiagrams/AppComposition")
	try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
	let existing = outputDirectory.appendingPathComponent("previous.mmd")
	try "previous output".write(to: existing, atomically: true, encoding: .utf8)
	try """
	#if DEBUG
	@DependencyGraph
	final class AppGraph {}
	#else
	@DependencyGraph
	final class AppGraph {}
	#endif
	""".write(to: source, atomically: true, encoding: .utf8)

	#expect(throws: DiagramOutputError.self) {
		try DiagramOutputWriter().write(
			request: DiagramOutputRequest(
				moduleName: "AppComposition",
				sourceURLs: [source],
				outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
			)
		)
	}
	#expect(try String(contentsOf: existing, encoding: .utf8) == "previous output")
}

// 중복 source accessor가 renderer 내부 충돌 대신 오류로 기존 산출물을 보존하는지 확인
@Test
func diagramOutputWriterPreservesExistingOutputWhenSourceAccessorsCollide() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	let outputDirectory = temporary.appendingPathComponent("CradleDiagrams/AppComposition")
	try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
	let existing = outputDirectory.appendingPathComponent("previous.mmd")
	try "previous output".write(to: existing, atomically: true, encoding: .utf8)
	try """
	@DependencyGraph(sources: [SessionGraph.self, SessionGraph.self])
	final class AppGraph {}
	""".write(to: source, atomically: true, encoding: .utf8)

	#expect(throws: DiagramOutputError.self) {
		try DiagramOutputWriter().write(
			request: DiagramOutputRequest(
				moduleName: "AppComposition",
				sourceURLs: [source],
				outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
			)
		)
	}
	#expect(try String(contentsOf: existing, encoding: .utf8) == "previous output")
}

// path 구성에 사용할 module 이름이 안전하지 않으면 기존 산출물을 유지하는지 확인
@Test
func diagramOutputWriterPreservesExistingOutputWhenModuleNameIsInvalid() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	let outputDirectory = temporary.appendingPathComponent("CradleDiagrams/ExampleApp")
	try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
	let existing = outputDirectory.appendingPathComponent("previous.mmd")
	try "previous output".write(to: existing, atomically: true, encoding: .utf8)
	try "@DependencyGraph final class AppGraph {}".write(to: source, atomically: true, encoding: .utf8)

	#expect(throws: DiagramOutputError.self) {
		try DiagramOutputWriter().write(
			request: DiagramOutputRequest(
				moduleName: "../ExampleApp",
				sourceURLs: [source],
				outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
			)
		)
	}
	#expect(try String(contentsOf: existing, encoding: .utf8) == "previous output")
}

// 공백·한글 target 이름과 source가 없는 빌드의 오래된 파일 정리 검증
@Test
func diagramOutputWriterAcceptsTargetDisplayNamesAndEmptySources() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	try "@DependencyGraph final class AppGraph {}".write(to: source, atomically: true, encoding: .utf8)
	let writer = DiagramOutputWriter()
	let outputs = try writer.write(request: DiagramOutputRequest(
		moduleName: "예제 App", sourceURLs: [source], outputDirectoryURL: temporary))
	#expect(outputs.count == 1)
	let removed = try writer.write(request: DiagramOutputRequest(
		moduleName: "예제 App", sourceURLs: [], outputDirectoryURL: temporary))
	#expect(removed.isEmpty)
	#expect(!FileManager.default.fileExists(atPath: outputs[0].path))
}

// source 참조와 provider 수명 node 테두리를 Mermaid로 표현하는지 확인
@Test
func diagramOutputWriterRendersSourceDependenciesAndLifetimeBorders() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	try """
	@DependencyGraph(sources: [SessionGraph.self])
	final class AppGraph {
		@Provide(.shared)
		private func makeRepository() -> Repository {
			Repository(session: sessionGraph.session)
		}

		@Provide(.transient)
		private func makeFeature(repository: Repository) -> Feature {
			Feature(repository: repository)
		}
	}
	""".write(to: source, atomically: true, encoding: .utf8)

	let output = try #require(
		DiagramOutputWriter().write(
			request: DiagramOutputRequest(
				moduleName: "AppComposition",
				sourceURLs: [source],
				outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
			)
		).first
	)
	let mermaid = try String(contentsOf: output, encoding: .utf8)

	#expect(
		mermaid.hasPrefix(
			"%% CradlePlugin이 생성한 의존성 graph\n"
				+ "%% 모든 조건부 컴파일 절을 포함하며 실제 활성 build condition을 뜻하지 않음\n"
				+ "%% plugin work directory 산출물이므로 swift package clean 뒤 사라질 수 있음\n"
		)
	)
	#expect(mermaid.contains("graph0_provider0 --> graph0_provider1"))
	#expect(mermaid.contains("graph0_provider1 --> graph0_source0"))
	#expect(mermaid.contains("classDef shared stroke:#333,stroke-width:2px;"))
	#expect(mermaid.contains("classDef transient stroke:#333,stroke-width:2px,stroke-dasharray:5 5;"))
}

// 구문 오류가 있으면 직전 성공 산출물을 유지하는지 확인
@Test
func diagramOutputWriterPreservesExistingOutputWhenSourceIsInvalid() throws {
	let temporary = try makeDiagramTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let source = temporary.appendingPathComponent("AppGraph.swift")
	let outputDirectory = temporary.appendingPathComponent("CradleDiagrams/AppComposition")
	try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
	let existing = outputDirectory.appendingPathComponent("previous.mmd")
	try "previous output".write(to: existing, atomically: true, encoding: .utf8)
	try "@DependencyGraph final class AppGraph {".write(to: source, atomically: true, encoding: .utf8)

	#expect(throws: DiagramOutputError.self) {
		try DiagramOutputWriter().write(
			request: DiagramOutputRequest(
				moduleName: "AppComposition",
				sourceURLs: [source],
				outputDirectoryURL: temporary.appendingPathComponent("CradleDiagrams")
			)
		)
	}
	#expect(try String(contentsOf: existing, encoding: .utf8) == "previous output")
}

// test마다 격리된 임시 산출물 디렉터리 생성
private func makeDiagramTemporaryDirectory() throws -> URL {
	let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	return directory
}
