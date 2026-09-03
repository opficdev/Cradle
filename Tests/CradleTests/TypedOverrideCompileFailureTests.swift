//
//  TypedOverrideCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Foundation
import Testing

// 타입 지정 override fixture의 종료 상태와 compiler 출력
private struct TypedOverrideCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// 타입·중복 label·actor capture·생성 제약이 원본 위치에서 거부되는지 확인
@Test
func typedOverrideCompileFailuresReportOriginalLocations() throws {
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/TypedOverrideInvalidUsage")
	let source = fixture.appendingPathComponent("Sources/TypedOverrideInvalidUsage/main.swift")
	let result = try buildTypedOverrideFixture(at: fixture)

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	#expect(result.output.contains("\(source.path):25:2: error: `overrides: true` graph는 initializer를 직접 선언할 수 없습니다."))
	#expect(result.output.contains("\(source.path):30:14: error: `overrides: true` graph는 초기값 없는 인스턴스 저장 프로퍼티를 선언할 수 없습니다."))
	#expect(result.output.contains("\(source.path):35:2: error: 타입 지정 override가 생성할 `override` 이름이 기존 member와 충돌합니다."))
	#expect(result.output.contains("\(source.path):42:32: error: extra argument 'typedOverrideFixtureService' in call"))
	#expect(result.output.contains("\(source.path):48:42: error: contextual closure type '() -> TypedOverrideFixtureService' expects 0 arguments"))
	#expect(result.output.contains("\(source.path):55:3: error: cannot convert value of type 'Int' to closure result type 'TypedOverrideFixtureService'"))
	#expect(result.output.contains("\(source.path):63:8: error: capture of 'capture' with non-Sendable type 'TypedOverrideNonSendableCapture'"))
	#expect(result.output.contains("\(source.path):86:40: error: cannot convert value of type '(Int) -> TypedOverrideFixtureService' to expected argument type '(TypedOverrideFixtureInput) -> TypedOverrideFixtureService'"))
}

// fixture 실행 없이 별도 scratch 경로에서 엄격한 동시성 Swift build와 진단 수집
private func buildTypedOverrideFixture(at fixture: URL) throws -> TypedOverrideCompileResult {
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
	return TypedOverrideCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
