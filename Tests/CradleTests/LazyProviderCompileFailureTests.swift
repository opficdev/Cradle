//
//  LazyProviderCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/6/26.
//

import Foundation
import Testing

// lazy provider compiler fixture의 종료 상태와 진단 출력
private struct LazyProviderCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// lazy 수명 연결과 외부 입력 제한이 원본 위치에서 거부되는지 확인
@Test
func lazyProviderCompileFailuresReportOriginalLocations() throws {
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/LazyProviderInvalidUsage")
	let source = fixture.appendingPathComponent("Sources/LazyProviderInvalidUsage/main.swift")
	let result = try buildLazyProviderFixture(at: fixture)
	let errors = [
		"\(source.path):18:9: error: shared 수명의 `@Provide` Factory는 `.lazy` 등록을 매개변수로 받을 수 없습니다.",
		"\(source.path):34:9: error: lazy 수명의 `@Provide` Factory는 `.transient` 등록을 매개변수로 받을 수 없습니다.",
		"\(source.path):45:3: error: `@External`은 명시적인 `@Provide(.transient)`에서만 사용할 수 있습니다.",
		"순환 의존성이 있습니다."
	]

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	for error in errors {
		#expect(result.output.contains(error))
	}
}

// fixture 실행 없이 별도 scratch 경로에서 compiler 진단 수집
private func buildLazyProviderFixture(at fixture: URL) throws -> LazyProviderCompileResult {
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
		"-Xswiftc", "-diagnostic-style", "-Xswiftc", "llvm"
	]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	try handle.close()
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	return LazyProviderCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
