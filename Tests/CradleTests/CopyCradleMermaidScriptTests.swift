//
//  CopyCradleMermaidScriptTests.swift
//  CradleTests
//
//  Created by opfic on 9/5/26.
//

import Foundation
import Testing

// percent-encoded Xcode target namespace의 Mermaid 복사 확인
@Test
func copyCradleMermaidScriptFindsEncodedTargetOutput() throws {
	let temporary = try makeCopyScriptTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }
	let output = temporary.appendingPathComponent(
		"BuildToolPluginIntermediates/ExampleApp.output/My.App/CradlePlugin/CradleDiagrams/My%2EApp/DependencyGraph.mmd"
	)
	try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
	try "graph TD\n".write(to: output, atomically: true, encoding: .utf8)

	let project = temporary.appendingPathComponent("project")
	let targetTemporary = temporary.appendingPathComponent("target-temporary")
	try FileManager.default.createDirectory(at: targetTemporary, withIntermediateDirectories: true)
	let process = try runCopyCradleMermaidScript(
		objroot: temporary,
		sourceRoot: project,
		targetTemporary: targetTemporary,
		targetName: "My.App"
	)

	#expect(process.terminationReason == .exit)
	#expect(process.terminationStatus == 0)
	#expect(try String(contentsOf: project.appendingPathComponent(".cradle/DependencyGraph.mmd"), encoding: .utf8) == "graph TD\n")
}

// source 없음과 복수 후보에서 기존 Mermaid 복사본 보존 확인
@Test
func copyCradleMermaidScriptPreservesExistingOutputForMissingOrMultipleCandidates() throws {
	let temporary = try makeCopyScriptTemporaryDirectory()
	defer { try? FileManager.default.removeItem(at: temporary) }

	let missingProject = temporary.appendingPathComponent("missing-project")
	let missingDestination = missingProject.appendingPathComponent(".cradle/DependencyGraph.mmd")
	let missingTargetTemporary = temporary.appendingPathComponent("missing-target-temporary")
	try FileManager.default.createDirectory(at: missingDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
	try FileManager.default.createDirectory(at: missingTargetTemporary, withIntermediateDirectories: true)
	try "previous missing\n".write(to: missingDestination, atomically: true, encoding: .utf8)
	let missingProcess = try runCopyCradleMermaidScript(
		objroot: temporary.appendingPathComponent("missing-objroot"),
		sourceRoot: missingProject,
		targetTemporary: missingTargetTemporary,
		targetName: "My.App"
	)

	#expect(missingProcess.terminationStatus == 0)
	#expect(try String(contentsOf: missingDestination, encoding: .utf8) == "previous missing\n")

	let multipleRoot = temporary.appendingPathComponent("multiple-objroot")
	let multipleProject = temporary.appendingPathComponent("multiple-project")
	let multipleDestination = multipleProject.appendingPathComponent(".cradle/DependencyGraph.mmd")
	let multipleTargetTemporary = temporary.appendingPathComponent("multiple-target-temporary")
	try FileManager.default.createDirectory(at: multipleDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
	try FileManager.default.createDirectory(at: multipleTargetTemporary, withIntermediateDirectories: true)
	try "previous multiple\n".write(to: multipleDestination, atomically: true, encoding: .utf8)
	for outputName in ["first", "second"] {
		let output = multipleRoot.appendingPathComponent(
			"BuildToolPluginIntermediates/\(outputName)/My.App/CradlePlugin/CradleDiagrams/My%2EApp/DependencyGraph.mmd"
		)
		try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
		try "new output\n".write(to: output, atomically: true, encoding: .utf8)
	}
	let multipleProcess = try runCopyCradleMermaidScript(
		objroot: multipleRoot,
		sourceRoot: multipleProject,
		targetTemporary: multipleTargetTemporary,
		targetName: "My.App"
	)

	#expect(multipleProcess.terminationStatus == 0)
	#expect(try String(contentsOf: multipleDestination, encoding: .utf8) == "previous multiple\n")
}

// shell script 실행에 사용할 임시 경로 생성
private func makeCopyScriptTemporaryDirectory() throws -> URL {
	let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
	return temporary
}

// build setting을 주입해 ExampleApp Mermaid 복사 script 실행
private func runCopyCradleMermaidScript(
	objroot: URL,
	sourceRoot: URL,
	targetTemporary: URL,
	targetName: String
) throws -> Process {
	let script = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("Examples/ExampleApp/Scripts/CopyCradleMermaid.sh")
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/bin/sh")
	process.arguments = [script.path]
	process.environment = ProcessInfo.processInfo.environment.merging([
		"OBJROOT": objroot.path,
		"SRCROOT": sourceRoot.path,
		"TARGET_TEMP_DIR": targetTemporary.path,
		"TARGET_NAME": targetName
	]) { _, value in value }
	try process.run()
	process.waitUntilExit()
	return process
}
