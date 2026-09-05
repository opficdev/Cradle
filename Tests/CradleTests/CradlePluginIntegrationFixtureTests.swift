//
//  CradlePluginIntegrationFixtureTests.swift
//  CradleTests
//
//  Created by opfic on 9/4/26.
//

import Foundation
import Testing

// 독립 소비자 package의 plugin build 결과
private struct CradlePluginFixtureResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// plugin과 compiler 출력
	let output: String
	// plugin work directory 아래 생성한 Mermaid 파일 경로
	let diagramPaths: [String]
	// Mermaid 파일별 생성 content
	let diagramContents: [String]
}

// 소비자 target build가 Mermaid를 plugin work directory에만 생성하는지 확인
@Test
func cradlePluginConsumerBuildCreatesMermaidOutputOutsideTargetSources() throws {
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("IntegrationFixtures/CradlePluginConsumer")
	let result = try buildCradlePluginFixture(at: fixture)

	#expect(result.terminationReason == .exit)
	#expect(result.status == 0, Comment(rawValue: result.output))
	#expect(result.diagramPaths.count == 1)
	#expect(result.diagramPaths.allSatisfy { path in
		path.hasSuffix("CradleDiagrams/AppComposition/DependencyGraph.mmd") && !path.contains(".bundle")
	})
	#expect(result.diagramContents.contains {
		$0.contains("AppGraph") && $0.contains("graph0_provider0 --> graph0_provider1")
	})
	#expect(result.diagramContents.contains { $0.contains("class graph0_provider0 transient") })
	#expect(result.diagramContents.contains { $0.contains("ExplicitGraph") })
	#expect(result.diagramContents.contains { $0.contains("ExternalGraph") && !$0.contains("ExternalFeature") })
	#expect(result.diagramContents.contains { $0.contains("Composition.NestedGraph") })
	#expect(result.diagramContents.contains { $0.contains("ExtensionFeatureA.AppGraph") })
	#expect(result.diagramContents.contains { $0.contains("ExtensionFeatureB.AppGraph") })
	#expect(!result.diagramContents.contains { $0.contains("ExcludedGraph") || $0.contains("UnrelatedFeature") })
}

// 독립 소비자 package를 별도 scratch 경로에서 build하고 Mermaid 산출물 수집
private func buildCradlePluginFixture(at fixture: URL) throws -> CradlePluginFixtureResult {
	let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	let scratch = temporary.appendingPathComponent("scratch")
	// 반복 빌드에서 원본 fixture를 변경하지 않을 작업 복사본
	let working = temporary.appendingPathComponent("fixture")
	let outputFile = temporary.appendingPathComponent("build-output.log")
	try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
	defer {
		try? FileManager.default.removeItem(at: temporary)
	}
	try FileManager.default.copyItem(at: fixture, to: working)
	let manifest = working.appendingPathComponent("Package.swift")
	let root = fixture.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
	let package = try String(contentsOf: manifest, encoding: .utf8)
		.replacingOccurrences(of: "\"../../..\"", with: String(reflecting: root.path))
	try package.write(to: manifest, atomically: true, encoding: .utf8)
	guard FileManager.default.createFile(atPath: outputFile.path, contents: nil) else {
		throw CocoaError(.fileWriteUnknown)
	}
	let handle = try FileHandle(forWritingTo: outputFile)
	defer {
		try? handle.close()
	}
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = [
		"swift", "build",
		"--package-path", working.path,
		"--scratch-path", scratch.path
	]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	try handle.close()
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	let diagrams = try mermaidFiles(in: scratch)
	let result = CradlePluginFixtureResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output,
		diagramPaths: diagrams.map(\.path),
		diagramContents: try diagrams.map { url in
			try String(contentsOf: url, encoding: .utf8)
		}
	)
	if process.terminationStatus == 0 {
		try verifyCradlePluginRebuilds(at: working, scratch: scratch, log: outputFile)
	}
	return result
}

// 같은 scratch 경로의 반복 빌드와 오류 이후 산출물 보존 검증
private func verifyCradlePluginRebuilds(at fixture: URL, scratch: URL, log: URL) throws {
	let initial = try diagramSnapshot(in: scratch)
	try rebuildCradlePluginFixture(at: fixture, scratch: scratch, log: log, succeeds: true)
	#expect(try diagramSnapshot(in: scratch) == initial)
	let source = fixture.appendingPathComponent("Sources/AppComposition/AppGraph.swift")
	let original = try String(contentsOf: source, encoding: .utf8)
	let renamed = original.replacingOccurrences(of: "ExplicitGraph", with: "RenamedGraph")
	try renamed.write(to: source, atomically: true, encoding: .utf8)
	try rebuildCradlePluginFixture(at: fixture, scratch: scratch, log: log, succeeds: true)
	let output = try #require(mermaidFiles(in: scratch).first)
	#expect(output.lastPathComponent == "DependencyGraph.mmd")
	let content = try String(contentsOf: output, encoding: .utf8)
	#expect(content.contains("RenamedGraph") && !content.contains("ExplicitGraph"))
	let disabled = renamed.replacingOccurrences(of: "@Cradle.DependencyGraph(diagram: true)",
		with: "@Cradle.DependencyGraph(diagram: false)")
	try disabled.write(to: source, atomically: true, encoding: .utf8)
	try rebuildCradlePluginFixture(at: fixture, scratch: scratch, log: log, succeeds: true)
	#expect(try mermaidFiles(in: scratch).count == 1)
	#expect(try !String(contentsOf: output, encoding: .utf8).contains("RenamedGraph"))
	let successful = try diagramSnapshot(in: scratch)
	let duplicate = """
	#if DEBUG
	@DependencyGraph final class DuplicateGraph {}
	#else
	@DependencyGraph final class DuplicateGraph {}
	#endif
	"""
	try (disabled + "\n" + duplicate).write(to: source, atomically: true, encoding: .utf8)
	let diagnostic = try rebuildCradlePluginFixture(at: fixture, scratch: scratch, log: log, succeeds: false)
	#expect(diagnostic.contains("중복된 DependencyGraph") && diagnostic.contains(source.path))
	#expect(try diagramSnapshot(in: scratch) == successful)
	try "@DependencyGraph final class Broken {".write(to: source, atomically: true, encoding: .utf8)
	try rebuildCradlePluginFixture(at: fixture, scratch: scratch, log: log, succeeds: false)
	#expect(try diagramSnapshot(in: scratch) == successful)
	// target는 유지하고 graph가 있는 source 파일을 삭제한 상황 검증
	try FileManager.default.removeItem(at: source)
	try "struct Placeholder {}".write(to: source.deletingLastPathComponent().appendingPathComponent("Keep.swift"),
		atomically: true, encoding: .utf8)
	try rebuildCradlePluginFixture(at: fixture, scratch: scratch, log: log, succeeds: true)
	#expect(try mermaidFiles(in: scratch).isEmpty)
	#expect(try mermaidFiles(in: fixture).isEmpty)
}

// 파일 내용과 수정 시각을 함께 보존하는 비교용 상태
private func diagramSnapshot(in directory: URL) throws -> [String: String] {
	try Dictionary(uniqueKeysWithValues: mermaidFiles(in: directory).map { url in
		let date = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
		let content = try String(contentsOf: url, encoding: .utf8)
		return (url.path, "\(String(describing: date?.timeIntervalSinceReferenceDate))\n\(content)")
	})
}

// 실행마다 새 Process를 만들어 성공·실패와 도구 출력을 확인
@discardableResult
private func rebuildCradlePluginFixture(at fixture: URL, scratch: URL, log: URL, succeeds: Bool) throws -> String {
	let handle = try FileHandle(forWritingTo: log)
	defer { try? handle.close() }
	try handle.truncate(atOffset: 0)
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = ["swift", "build", "--package-path", fixture.path, "--scratch-path", scratch.path]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	let output = try String(contentsOf: log, encoding: .utf8)
	#expect(process.terminationReason == .exit)
	#expect((process.terminationStatus == 0) == succeeds, Comment(rawValue: output))
	return output
}

// SwiftPM scratch directory에서 plugin이 생성한 `.mmd` 파일만 수집
private func mermaidFiles(in directory: URL) throws -> [URL] {
	let enumerator = FileManager.default.enumerator(
		at: directory,
		includingPropertiesForKeys: [.isRegularFileKey]
	)
	let urls = try enumerator?.compactMap { element -> URL? in
		guard let url = element as? URL,
			url.pathExtension == "mmd",
			try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
			return nil
		}
		return url
	} ?? []
	return urls.sorted { $0.path < $1.path }
}
