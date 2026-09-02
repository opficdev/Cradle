//
//  ActorGraphCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Foundation
import Testing

// actor graph compiler fixture의 종료 상태와 진단 출력
private struct ActorGraphCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// actor 경계 non-Sendable 반환과 shared Factory actor 상태 참조 거부 확인
@Test
func actorGraphCompileFailuresPreserveCompilerOwnership() throws {
	let fixtures = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures")
	let nonSendableFixture = fixtures.appendingPathComponent("ActorGraphNonSendableBoundary")
	let nonSendableSource = nonSendableFixture
		.appendingPathComponent("Sources/ActorGraphNonSendableBoundary/main.swift")
	let isolationFixture = fixtures.appendingPathComponent("ActorGraphSharedIsolation")
	let nonSendableResult = try buildActorGraphFixture(at: nonSendableFixture)
	let isolationResult = try buildActorGraphFixture(at: isolationFixture)
	let nonSendableError = "\(nonSendableSource.path):24:18: error: non-Sendable type "
		+ "'ActorGraphNonSendableService' of property 'actorGraphNonSendableService' "
		+ "cannot exit actor-isolated context"

	#expect(nonSendableResult.terminationReason == .exit)
	#expect(nonSendableResult.status != 0)
	#expect(nonSendableResult.output.contains(nonSendableError))
	#expect(isolationResult.terminationReason == .exit)
	#expect(isolationResult.status != 0)
	#expect(isolationResult.output.contains("instance member 'sequence' cannot be used on type"))
}

// fixture 실행 없이 별도 scratch 경로에서 엄격한 동시성 Swift build와 진단 수집
private func buildActorGraphFixture(at fixture: URL) throws -> ActorGraphCompileResult {
	let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	let scratch = temporary.appendingPathComponent("scratch")
	let outputFile = temporary.appendingPathComponent("compiler-output.log")
	try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
	defer {
		try? FileManager.default.removeItem(at: temporary)
	}
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
		"--package-path", fixture.path,
		"--scratch-path", scratch.path,
		"-Xswiftc", "-strict-concurrency=complete",
		"-Xswiftc", "-diagnostic-style", "-Xswiftc", "llvm"
	]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	try handle.close()
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	return ActorGraphCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
