//
//  CircularDependencyCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Foundation
import Testing

// 순환 진단 fixture의 프로세스 종료 상태와 컴파일러 출력
private struct CircularDependencyCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift 빌드 종료 코드
	let status: Int32
	// 원본 위치를 포함한 컴파일러 진단
	let output: String
}

// 두 그래프의 원본 매개변수 오류와 각 등록의 보조 설명 확인
@Test
func circularDependencyCompileFailureReportsOriginalLocations() throws {
	// 현재 테스트 위치를 기준으로 찾은 컴파일 전용 패키지
	let fixture = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/CircularDependency")
	// 진단이 가리켜야 하는 원본 소스
	let source = fixture.appendingPathComponent("Sources/CircularDependency/main.swift")
	// 실행파일을 실행하지 않고 수집한 빌드 결과
	let result = try buildCircularDependencyFixture(at: fixture)
	// 자기 순환과 세 등록 순환의 닫는 원본 매개변수 오류
	let errors = [
		"\(source.path):24:32: error: `firstService → firstService` 순환 의존성이 있습니다.",
		"\(source.path):41:19: error: `firstService → secondService → thirdService → firstService` 순환 의존성이 있습니다."
	]
	// 자기 순환 등록 하나와 다중 순환 등록 세 개의 원본 위치
	let notes = [
		(23, "makeFirstService", "firstService"),
		(31, "makeFirstService", "firstService"),
		(35, "makeSecondService", "secondService"),
		(39, "makeThirdService", "thirdService")
	]
		.map { line, factory, accessor in
			"\(source.path):\(line):2: note: `\(factory)` Factory의 등록입니다. 생성 접근자는 `\(accessor)`입니다."
		}

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	for error in errors {
		#expect(result.output.contains(error))
	}
	for note in notes {
		#expect(result.output.contains(note))
	}
}

// 기존 fixture 방식으로 전용 임시 경로에서 빌드하고 파일 출력 수집
private func buildCircularDependencyFixture(at fixture: URL) throws -> CircularDependencyCompileResult {
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
	return CircularDependencyCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
