//
//  MultiModuleCompositionFixtureTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Foundation
import Testing

// 독립 fixture test의 종료 상태와 compiler 출력
private struct MultiModuleCompositionFixtureResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift test 종료 코드
	let status: Int32
	// fixture build와 test 출력
	let output: String
}

// 독립 package에서 다중 모듈 graph 조합 검증 실행
@Test
func multiModuleCompositionFixturePackagePasses() throws {
	// 독립 다중 모듈 fixture package 경로
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("IntegrationFixtures/MultiModuleComposition")
	// fixture package test 실행 결과
	let result = try testMultiModuleCompositionFixture(at: fixture)

	#expect(result.terminationReason == .exit)
	#expect(result.status == 0, Comment(rawValue: result.output))
}

// 별도 scratch 경로에서 fixture package test 실행
private func testMultiModuleCompositionFixture(
	at fixture: URL
) throws -> MultiModuleCompositionFixtureResult {
	// fixture 산출물을 함께 정리할 임시 directory
	let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	// SwiftPM build artifact 전용 scratch 경로
	let scratch = temporary.appendingPathComponent("scratch")
	// Swift test output 기록 file 경로
	let outputFile = temporary.appendingPathComponent("test-output.log")
	try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
	defer {
		try? FileManager.default.removeItem(at: temporary)
	}
	guard FileManager.default.createFile(atPath: outputFile.path, contents: nil) else {
		throw CocoaError(.fileWriteUnknown)
	}
	// Swift test output 기록 handle
	let handle = try FileHandle(forWritingTo: outputFile)
	defer {
		try? handle.close()
	}
	// fixture package에서 test를 실행할 process
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = [
		"swift", "test",
		"--package-path", fixture.path,
		"--scratch-path", scratch.path
	]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	try handle.close()
	// fixture package의 compiler와 test 출력
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	return MultiModuleCompositionFixtureResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
