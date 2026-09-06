//
//  SharedGraphCompileFixtureTests.swift
//  CradleTests
//
//  Created by opfic on 9/6/26.
//

import Foundation
import Testing

// shared graph compiler fixture의 종료 상태와 진단 출력
private struct SharedGraphCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// compiler 표준 출력과 오류 출력
	let output: String
}

// 허용한 graph 격리와 source 정적 접근이 strict concurrency에서 빌드되는지 확인
@Test
func sharedGraphAllowedUsageCompiles() throws {
	let result = try buildSharedGraphFixture(
		at: sharedGraphFixture(named: "SharedGraphAllowedUsage")
	)

	#expect(result.terminationReason == .exit)
	#expect(result.status == 0, Comment(rawValue: result.output))
}

// Macro 진단과 compiler 소유 동시성·source 접근 오류가 원본 위치에서 나타나는지 확인
@Test
func sharedGraphInvalidUsagePreservesDiagnostics() throws {
	let fixture = sharedGraphFixture(named: "SharedGraphInvalidUsage")
	let source = fixture.appendingPathComponent("Sources/SharedGraphInvalidUsage/main.swift")
	let result = try buildSharedGraphFixture(at: fixture)
	let errors = [
		"\(source.path):7:18: error: 비격리 `final class`에서 `.shared`를 사용하려면 선언에 checked `Sendable` 준수를 직접 작성해야 합니다.",
		"\(source.path):10:18: error: 비격리 `final class`의 `.shared`에는 `@unchecked Sendable`을 사용할 수 없습니다.",
		"of 'Sendable'-conforming class 'SharedGraphLazy' is mutable",
		"of 'Sendable'-conforming class 'SharedGraphNonSendableProvider' has non-Sendable type",
		"has no member 'shared'",
		"cannot convert value of type 'SharedGraphWrongStaticValue' to specified type",
		"'shared' is inaccessible due to 'private' protection level",
		"main actor-isolated default value in a nonisolated context",
		"static property 'shared' is not concurrency-safe because non-'Sendable' type "
			+ "'SharedGraphNonSendableSource' may have shared mutable state",
		"non-Sendable type 'SharedGraphActorNonSendableService' of property "
			+ "'sharedGraphActorNonSendableService' cannot exit actor-isolated context",
		"capture of 'capture' with non-Sendable type 'SharedGraphInvalidCapture'"
	]

	#expect(result.terminationReason == .exit)
	#expect(result.status != 0)
	for error in errors {
		#expect(result.output.contains(error))
	}
}

// 이름으로 선택한 shared graph compiler fixture 경로
private func sharedGraphFixture(named name: String) -> URL {
	URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures")
		.appendingPathComponent(name)
}

// fixture 실행 없이 별도 scratch 경로에서 엄격한 동시성 Swift build와 진단 수집
private func buildSharedGraphFixture(at fixture: URL) throws -> SharedGraphCompileResult {
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
	return SharedGraphCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
