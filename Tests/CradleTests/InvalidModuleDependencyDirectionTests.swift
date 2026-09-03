//
//  InvalidModuleDependencyDirectionTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Foundation
import Testing

// 역방향 import fixture의 종료 상태와 compiler 출력
private struct InvalidModuleDependencyDirectionResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// 원본 위치를 포함한 compiler 진단
	let output: String
}

// Domain에서 Data를 import하면 원본 위치에서 거부되는지 확인
@Test
func invalidModuleDependencyDirectionFailsAtDomainImport() throws {
	// 역방향 import compile-fail fixture package 경로
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/InvalidModuleDependencyDirection")
	// 잘못된 import를 작성한 Domain 원본 file
	let source = fixture.appendingPathComponent("Sources/Domain/Domain.swift")
	// Domain target build 결과
	let result = try buildInvalidModuleDependencyDirectionFixture(at: fixture)

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	#expect(result.output.contains(
		"\(source.path):8:8: error: no such module 'Data'"
	), Comment(rawValue: result.output))
}

// fixture 실행 없이 별도 scratch 경로에서 Domain target build
private func buildInvalidModuleDependencyDirectionFixture(
	at fixture: URL
) throws -> InvalidModuleDependencyDirectionResult {
	// fixture 산출물을 함께 정리할 임시 directory
	let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	// SwiftPM build artifact 전용 scratch 경로
	let scratch = temporary.appendingPathComponent("scratch")
	// compiler output 기록 file 경로
	let outputFile = temporary.appendingPathComponent("compiler-output.log")
	try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
	defer {
		try? FileManager.default.removeItem(at: temporary)
	}
	guard FileManager.default.createFile(atPath: outputFile.path, contents: nil) else {
		throw CocoaError(.fileWriteUnknown)
	}
	// compiler output 기록 handle
	let handle = try FileHandle(forWritingTo: outputFile)
	defer {
		try? handle.close()
	}
	// Domain target만 빌드할 process
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = [
		"swift", "build",
		"--package-path", fixture.path,
		"--scratch-path", scratch.path,
		"--target", "Domain",
		"-Xswiftc", "-diagnostic-style", "-Xswiftc", "llvm"
	]
	process.standardOutput = handle
	process.standardError = handle
	try process.run()
	process.waitUntilExit()
	try handle.close()
	// Domain target의 compiler 출력
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	return InvalidModuleDependencyDirectionResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
