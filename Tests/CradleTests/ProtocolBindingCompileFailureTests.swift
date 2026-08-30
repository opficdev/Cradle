//
//  ProtocolBindingCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Foundation
import Testing

// fixture 빌드 종료 상태와 오류 출력 보관
private struct ProtocolBindingCompileResult {
	// 정상 종료와 신호 종료의 구분
	let terminationReason: Process.TerminationReason
	// Swift 빌드 종료 코드
	let status: Int32
	// 컴파일러의 표준 출력과 오류 출력
	let output: String
}

// 프로토콜 반환·인자 전달·공개 접근 수준의 오류를 Swift 컴파일러가 거부하는지 확인
@Test
func protocolBindingRejectsInvalidConsumerPrograms() throws {
	// 의도한 오류별 fixture와 반드시 포함할 타입 이름
	let cases = [
		("ProtocolBindingNonconformingImplementation", ["NonconformingRepository", "RequiredRepository"]),
		("ProtocolBindingMismatchedDependency", ["ProvidedRepository", "ExpectedRepository"]),
		("PublicGraphLeaksInternalProtocol", ["InternalRepositoryContract"])
	]

	for (name, requiredTypes) in cases {
		// 각 fixture를 순차 빌드한 결과
		let result = try buildProtocolBindingFixture(named: name)
		#expect(result.terminationReason == .exit)
		#expect(result.status != 0)
		#expect(result.output.contains("error:"))
		#expect(result.output.contains("main.swift:"))
		#expect(!result.output.contains("`@Provide` 반환 타입은"))
		for type in requiredTypes {
			#expect(result.output.contains(type))
		}

		if name == "ProtocolBindingNonconformingImplementation" {
			#expect(result.output.contains("return expression of type"))
			#expect(result.output.contains("does not conform"))
		} else if name == "ProtocolBindingMismatchedDependency" {
			#expect(result.output.contains("does not conform") || result.output.contains("cannot convert"))
		} else {
			#expect(result.output.contains("method cannot be declared public"))
			#expect(result.output.contains("internal type"))
		}
	}
}

// 개별 fixture를 실행하지 않고 빌드해 종료 상태와 진단 수집
private func buildProtocolBindingFixture(named name: String) throws -> ProtocolBindingCompileResult {
	// 현재 테스트 파일을 기준으로 찾은 fixture package
	let fixtureDirectory = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures")
		.appendingPathComponent(name)
	// 해당 빌드에서만 사용하는 임시 디렉터리
	let temporaryDirectory = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	// SwiftPM 산출물 경로
	let scratchDirectory = temporaryDirectory.appendingPathComponent("scratch")
	// 대량 출력의 pipe 교착을 피할 기록 파일
	let outputFileURL = temporaryDirectory.appendingPathComponent("compiler-output.log")
	try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
	defer {
		try? FileManager.default.removeItem(at: temporaryDirectory)
	}
	// 프로세스 출력 파일 생성 결과
	let createdOutputFile = FileManager.default.createFile(atPath: outputFileURL.path, contents: nil)
	guard createdOutputFile else {
		throw CocoaError(.fileWriteUnknown)
	}
	// 표준 출력과 오류를 함께 기록할 핸들
	let outputFileHandle = try FileHandle(forWritingTo: outputFileURL)
	defer {
		try? outputFileHandle.close()
	}
	// 실행파일을 실행하지 않는 SwiftPM 빌드 프로세스
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = [
		"swift", "build",
		"--package-path", fixtureDirectory.path,
		"--scratch-path", scratchDirectory.path
	]
	process.standardOutput = outputFileHandle
	process.standardError = outputFileHandle
	try process.run()
	process.waitUntilExit()
	try outputFileHandle.close()
	// 빌드가 끝난 뒤 읽은 전체 진단
	let output = String(data: try Data(contentsOf: outputFileURL), encoding: .utf8) ?? ""
	return ProtocolBindingCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
