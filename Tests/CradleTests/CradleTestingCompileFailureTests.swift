//
//  CradleTestingCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Foundation
import Testing

// CradleTesting fixture 빌드의 종료 상태와 compiler 출력
private struct CradleTestingCompileResult {
	// 정상 종료와 신호 종료의 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// mock label·Factory 형식·actor capture 오류의 원본 위치 확인
@Test
func cradleTestingCompileFailureReportsMockSourceLocations() throws {
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/CradleTestingInvalidUsage")
	let source = fixture.appendingPathComponent("Sources/CradleTestingInvalidUsage/main.swift")
	let result = try buildCradleTestingFixture(at: fixture)
	let errors = [
		"\(source.path):41:12: error: extra argument 'unknown' in call",
		"\(source.path):50:32: error: extra argument 'cradleTestingFixtureService' in call",
		"\(source.path):56:39: error: contextual closure type '() -> CradleTestingFixtureService' expects 0 arguments, but 1 was used in closure body",
		"\(source.path):63:3: error: cannot convert value of type 'Int' to closure result type 'CradleTestingFixtureService'",
		"\(source.path):71:8: error: capture of 'capture' with non-Sendable type 'CradleTestingNonSendableCapture'",
		"\(source.path):78:37: error: cannot convert value of type '(Int) -> CradleTestingFixtureService' to expected argument type '(CradleTestingFixtureInput) -> CradleTestingFixtureService'"
	]

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	for error in errors {
		#expect(result.output.contains(error))
	}
}

// fixture 실행 없이 별도 scratch 경로에서 compiler 진단 수집
private func buildCradleTestingFixture(at fixture: URL) throws -> CradleTestingCompileResult {
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
	return CradleTestingCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
