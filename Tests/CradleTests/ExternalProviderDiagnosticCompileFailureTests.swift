//
//  ExternalProviderDiagnosticCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/4/26.
//

import Foundation
import Testing

// 외부 입력 compiler fixture의 종료 상태와 출력
private struct ExternalProviderDiagnosticCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// 외부 입력 Macro 진단이 원본 위치에 표시되는지 확인
@Test
func externalProviderDiagnosticCompileFailuresReportOriginalLocations() throws {
	let fixture = externalProviderDiagnosticFixture(named: "ExternalProviderInvalidUsage")
	let source = fixture.appendingPathComponent("Sources/ExternalProviderInvalidUsage/main.swift")
	let result = try buildExternalProviderDiagnosticFixture(at: fixture)
	let errors = [
		"\(source.path):11:3: error: `@External`은 명시적인 `@Provide(.transient)`에서만 사용할 수 있습니다.",
		"\(source.path):28:12: error: `ExternalProviderInvalidProfile`은 `@External` 입력이 필요한 생성 결과이므로 graph 의존성으로 자동 연결할 수 없습니다.",
		"\(source.path):43:7: error: `externalProviderInvalidService` 생성 메서드 이름이 기존 graph 멤버와 충돌합니다."
	]

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	for error in errors {
		#expect(result.output.contains(error))
	}
}

// public 생성 메서드가 internal 입력·반환 타입을 노출하지 못하는지 확인
@Test
func externalProviderDiagnosticRejectsPublicInternalTypes() throws {
	let fixture = externalProviderDiagnosticFixture(named: "PublicExternalProviderLeaksInternalType")
	let result = try buildExternalProviderDiagnosticFixture(at: fixture)

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	#expect(result.output.contains("method cannot be declared public because its parameter uses an internal type"))
	#expect(result.output.contains("InternalExternalProviderInput"))
	#expect(result.output.contains("method cannot be declared public because its result uses an internal type"))
	#expect(result.output.contains("InternalExternalProviderResult"))
}

// 외부 입력 override Factory가 원본 전체 매개변수 형식을 요구하는지 확인
@Test
func externalProviderOverrideRejectsWrongFactorySignature() throws {
	let fixture = externalProviderDiagnosticFixture(named: "ExternalProviderOverrideInvalidUsage")
	let source = fixture.appendingPathComponent("Sources/ExternalProviderOverrideInvalidUsage/main.swift")
	let result = try buildExternalProviderDiagnosticFixture(at: fixture)
	let error = "\(source.path):23:45: error: contextual closure type "
		+ "'(ExternalProviderOverrideRepository, Int) -> ExternalProviderOverrideResult' "
		+ "expects 2 arguments, but 1 was used in closure body"

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	#expect(result.output.contains(error))
}

// 이름으로 선택한 외부 입력 compiler fixture 경로
private func externalProviderDiagnosticFixture(named name: String) -> URL {
	URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures")
		.appendingPathComponent(name)
}

// fixture 실행 없이 별도 scratch 경로에서 compiler 진단 수집
private func buildExternalProviderDiagnosticFixture(
	at fixture: URL
) throws -> ExternalProviderDiagnosticCompileResult {
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
	return ExternalProviderDiagnosticCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
