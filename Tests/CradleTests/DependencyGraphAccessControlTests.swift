//
//  DependencyGraphAccessControlTests.swift
//  CradleTests
//
//  Created by opfic on 8/29/26.
//

import CradleConsumerFixture
import Foundation
import Testing

// 별도 module의 public graph 접근자 호출 확인
@Test
func anotherModuleCanUsePublicGraphAccessor() {
	// fixture module이 제공한 public graph
	let graph = PublicGraph()

	_ = graph.publicService()
}

// public 접근자가 internal 반환 타입을 노출하는지 확인
@Test
func publicAccessorCannotExposeInternalReturnType() throws {
	// compile-fail fixture package 위치
	let fixtureDirectory = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/PublicGraphLeaksInternalService")
	// build 전용 임시 scratch 경로
	let scratchDirectory = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	defer {
		try? FileManager.default.removeItem(at: scratchDirectory)
	}
	// fixture build process
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = [
		"swift",
		"build",
		"--package-path",
		fixtureDirectory.path,
		"--scratch-path",
		scratchDirectory.path
	]
	// compiler output 수집 pipe
	let outputPipe = Pipe()
	process.standardOutput = outputPipe
	process.standardError = outputPipe

	try process.run()
	process.waitUntilExit()

	// access-control 오류 확인용 compiler output
	let output = String(
		data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
		encoding: .utf8
	) ?? ""

	#expect(process.terminationStatus != 0)
	#expect(output.contains("method cannot be declared public because its result uses an internal type"))
	#expect(output.contains("InternalService"))
}
