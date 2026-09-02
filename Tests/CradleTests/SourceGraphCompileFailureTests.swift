//
//  SourceGraphCompileFailureTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import Foundation
import Testing

// compile-fail fixture의 종료 상태와 compiler 출력
private struct SourceGraphCompileResult {
	// 정상 종료와 신호 종료 구분
	let terminationReason: Process.TerminationReason
	// Swift build 종료 코드
	let status: Int32
	// 원본 위치를 포함한 compiler 진단
	let output: String
}

// source 접근자 오류와 superclass initializer 오류를 Swift compiler가 표시하는지 확인
@Test
func sourceGraphInvalidUsageFailsAtBuildTime() throws {
	let fixtureDirectory = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures")
	let invalidUsageFixture = fixtureDirectory.appendingPathComponent("SourceGraphInvalidUsage")
	let invalidUsageSource = invalidUsageFixture
		.appendingPathComponent("Sources/SourceGraphInvalidUsage/main.swift")
	let superclassFixture = fixtureDirectory.appendingPathComponent("SourceGraphSuperclass")
	let superclassSource = superclassFixture
		.appendingPathComponent("Sources/SourceGraphSuperclass/main.swift")
	let invalidUsageResult = try buildSourceGraphFixture(at: invalidUsageFixture)
	let superclassResult = try buildSourceGraphFixture(at: superclassFixture)

	#expect(invalidUsageResult.terminationReason == .exit)
	#expect(invalidUsageResult.status != 0)
	#expect(invalidUsageResult.output.contains("\(invalidUsageSource.path):36:27: error: value of type 'SourceGraphGetterSource' has no member 'missingFeature'"))
	#expect(invalidUsageResult.output.contains("\(invalidUsageSource.path):51:28: error: 'privateFeature' is inaccessible due to 'private' protection level"))
	#expect(invalidUsageResult.output.contains("\(invalidUsageSource.path):60:27: error: cannot convert return expression of type 'SourceGraphActualFeature' to return type 'SourceGraphExpectedFeature'"))
	#expect(superclassResult.terminationReason == .exit)
	#expect(superclassResult.status != 0)
	#expect(superclassResult.output.contains("\(superclassSource.path)"))
	#expect(superclassResult.output.contains("error: 'super.init' isn't called on all paths before returning from initializer"))
}

// fixture 실행 없이 별도 scratch 경로에서 Swift build와 진단 수집
private func buildSourceGraphFixture(at fixture: URL) throws -> SourceGraphCompileResult {
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
	return SourceGraphCompileResult(
		terminationReason: process.terminationReason,
		status: process.terminationStatus,
		output: output
	)
}
