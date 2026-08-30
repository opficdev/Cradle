//
//  MissingProviderDependencyTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Foundation
import Testing

// 같은 이름의 일반 메서드가 있어도 누락 provider 연결이 빌드에 실패하는지 확인
@Test
func missingProviderDependencyFailsAtBuildTime() throws {
	// compile-fail fixture package 위치
	let fixtureDirectory = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/MissingProviderDependency")
	// fixture build 자료를 함께 정리할 임시 directory
	let temporaryDirectory = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	// SwiftPM build artifact 전용 scratch 경로
	let scratchDirectory = temporaryDirectory.appendingPathComponent("scratch")
	// compiler output 기록 file 경로
	let outputFileURL = temporaryDirectory.appendingPathComponent("compiler-output.log")
	try FileManager.default.createDirectory(
		at: temporaryDirectory,
		withIntermediateDirectories: true
	)
	defer {
		try? FileManager.default.removeItem(at: temporaryDirectory)
	}
	// compiler output file 생성 결과
	let createdOutputFile = FileManager.default.createFile(atPath: outputFileURL.path, contents: nil)
	guard createdOutputFile else {
		throw CocoaError(.fileWriteUnknown)
	}
	// compiler output 기록 file handle
	let outputFileHandle = try FileHandle(forWritingTo: outputFileURL)
	defer {
		try? outputFileHandle.close()
	}
	// fixture build process
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
	process.arguments = [
		"swift",
		"build",
		"--package-path",
		fixtureDirectory.path,
		"--scratch-path",
		scratchDirectory.path
	]
	process.standardOutput = outputFileHandle
	process.standardError = outputFileHandle

	try process.run()
	process.waitUntilExit()
	try outputFileHandle.close()

	// 누락 연결 오류 확인용 compiler output
	let output = String(data: try Data(contentsOf: outputFileURL), encoding: .utf8) ?? ""

	#expect(process.terminationReason == .exit)
	#expect(process.terminationStatus != 0)
	#expect(output.contains("지역 이름이 등록 생성 접근자와 일치해야 합니다"))
}
