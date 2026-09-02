//
//  BodylessProviderCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import Foundation
import Testing

// compile-fail fixture의 종료 상태와 진단 출력
private struct BodylessProviderCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// 본문 없는 추상 반환 Factory를 Swift compiler가 거부하는지 확인
@Test
func bodylessAbstractProviderFailsAtBuildTime() throws {
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/BodylessAbstractProvider")
	let result = try buildBodylessProviderFixture(at: fixture)

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	#expect(result.output.contains("error:"))
	#expect(result.output.contains("any Repository"))
	#expect(result.output.contains("cannot be constructed because it has no accessible initializers"))
	#expect(result.output.contains("RepositorySuperclass"))
	#expect(result.output.contains("inaccessible due to 'private' protection level"))
	#expect(result.output.contains("macro expansion @Provide"))
	#expect(!result.output.contains("`@Provide`의 반환 타입과 매개변수 타입에는 Optional을 사용할 수 없습니다."))
	#expect(!result.output.contains("`@Provide` 반환 타입은"))
}

// fixture 실행 없이 별도 scratch 경로에서 Swift build와 진단 수집
private func buildBodylessProviderFixture(at fixture: URL) throws -> BodylessProviderCompileResult {
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
		"--scratch-path", scratch.path
	]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	try handle.close()
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	return BodylessProviderCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
