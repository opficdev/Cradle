//
//  DuplicateRegistrationCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Foundation
import Testing

// 중복 등록 fixture 빌드의 종료 상태와 진단 출력
private struct DuplicateRegistrationCompileResult {
	// 정상 종료와 신호 종료의 구분
	let terminationReason: Process.TerminationReason
	// Swift 빌드 종료 코드
	let status: Int32
	// 컴파일러 표준 출력과 오류 출력
	let output: String
}

// 대표 반환 타입의 오류와 모든 등록의 보조 설명이 원본 위치를 가리키는지 확인
@Test
func duplicateRegistrationCompileFailureReportsOriginalLocations() throws {
	// 현재 테스트 파일을 기준으로 찾은 컴파일 실패 패키지
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/DuplicateRegistration")
	// 진단이 가리켜야 하는 원본 소스 파일
	let source = fixture.appendingPathComponent("Sources/DuplicateRegistration/main.swift")
	// fixture 실행 없이 수집한 빌드 결과
	let result = try buildDuplicateRegistrationFixture(at: fixture)
	// 주석 다음 원본 반환 타입의 첫 토큰에 표시할 오류
	let error = "\(source.path):28:16: error: `repository` 생성 접근자를 만드는 등록이 중복됩니다."
	// 대표를 포함한 모든 @Provide 위치와 백틱을 한 번만 인용한 Factory 이름
	let notes = [(26, "makeFirst"), (33, "makeSecond"), (39, "makeThird")].map { line, factory in
		"\(source.path):\(line):2: note: `\(factory)` Factory의 등록입니다. 반환 타입은 `any Repository`입니다."
	}

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	#expect(result.output.contains(error))
	for note in notes {
		#expect(result.output.contains(note))
	}
}

// 기존 fixture 방식으로 전용 임시 경로에서 빌드하고 파일 출력 수집
private func buildDuplicateRegistrationFixture(at fixture: URL) throws -> DuplicateRegistrationCompileResult {
	// 이번 검증의 빌드 자료를 함께 정리할 임시 디렉터리
	let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	// SwiftPM 빌드 산출물을 격리할 경로
	let scratch = temporary.appendingPathComponent("scratch")
	// 대량 출력의 파이프 교착을 피할 기록 파일
	let outputFile = temporary.appendingPathComponent("compiler-output.log")
	try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
	defer {
		try? FileManager.default.removeItem(at: temporary)
	}
	// 컴파일러 출력 파일 생성 결과
	let created = FileManager.default.createFile(atPath: outputFile.path, contents: nil)
	guard created else {
		throw CocoaError(.fileWriteUnknown)
	}
	// 표준 출력과 오류를 함께 기록할 핸들
	let handle = try FileHandle(forWritingTo: outputFile)
	defer {
		try? handle.close()
	}
	// fixture 실행파일을 실행하지 않는 SwiftPM 빌드 프로세스
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
	// 종료 후 읽은 전체 컴파일러 진단
	let output = String(data: try Data(contentsOf: outputFile), encoding: .utf8) ?? ""
	return DuplicateRegistrationCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
