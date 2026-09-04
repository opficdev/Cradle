//
//  DependencyGraphAccessControlTests.swift
//  CradleTests
//
//  Created by opfic on 8/29/26.
//

import CradleConsumerFixture
import Foundation
import Testing

// 별도 module의 public graph 접근자 호출 확인
@Test
func anotherModuleCanUsePublicGraphAccessor() {
	// fixture module이 제공한 public graph
	let graph = PublicGraph()

	_ = graph.publicService
}

// 별도 module의 public `@External` 생성 메서드 호출 확인
@Test
func externalProviderMethodIsAvailableFromAnotherModule() {
	let graph = PublicExternalProviderGraph()
	let service = graph.publicExternalProviderService(
		input: PublicExternalProviderInput(value: 29)
	)

	#expect(service.value == 29)
}

// 별도 module의 public actor 외부 입력 생성 메서드 await 호출 확인
@Test
func externalProviderActorMethodIsAvailableFromAnotherModule() async {
	let graph = PublicExternalProviderActorGraph()
	let service = await graph.publicExternalProviderService(
		input: PublicExternalProviderInput(value: 30)
	)

	#expect(service.value == 30)
}

// 별도 module의 public MainActor 외부 입력 생성 메서드 호출 확인
@Test
@MainActor
func externalProviderMainActorMethodIsAvailableFromAnotherModule() {
	let graph = PublicExternalProviderMainActorGraph()
	let service = graph.publicExternalProviderService(
		input: PublicExternalProviderInput(value: 31)
	)

	#expect(service.value == 31)
}

// 별도 module의 public override builder와 build 호출 확인
@Test
func anotherModuleCanBuildPublicTypedOverrideGraph() {
	let graph = PublicTypedOverrideGraph.override(
		publicTypedOverrideService: .replace {
			PublicTypedOverrideService(value: 11)
		}
	).build()

	#expect(graph.publicTypedOverrideService.value == 11)
}

// 별도 module의 public source graph override builder와 build 인자 호출 확인
@Test
func anotherModuleCanBuildPublicTypedOverrideSourceGraph() {
	let graph = PublicTypedOverrideSourceGraph.override(
		publicSourceService: .replace {
			PublicSourceService(token: 17)
		}
	).build(publicSourceGraph: PublicSourceGraph())

	#expect(graph.publicSourceService.token == 17)
}

// 별도 module의 public MainActor override builder와 build 호출 확인
@Test
@MainActor
func anotherModuleCanBuildPublicMainActorTypedOverrideGraph() {
	let graph = PublicMainActorTypedOverrideGraph.override(
		publicTypedOverrideService: .replace {
			PublicTypedOverrideService(value: 19)
		}
	).build()

	#expect(graph.publicTypedOverrideService.value == 19)
}

// 별도 module의 public actor graph 접근자 await 호출 확인
@Test
func anotherModuleCanAwaitPublicActorGraphAccessor() async {
	let graph = PublicActorGraph()
	let service = await graph.publicActorService
	let token = await service.token()

	#expect(token == 21)
}

// 별도 module의 public actor override builder와 Sendable build 호출 확인
@Test
func anotherModuleCanBuildPublicTypedOverrideActorGraph() async {
	let graph = PublicTypedOverrideActorGraph.override(
		publicTypedOverrideActorService: .replace {
			PublicTypedOverrideActorService(value: 14)
		}
	).build()
	let service = await graph.publicTypedOverrideActorService

	#expect(await service.token() == 14)
}

// public 접근자가 internal 반환 타입을 노출하는지 확인
@Test
func publicAccessorCannotExposeInternalReturnType() throws {
	// compile-fail fixture package 위치
	let fixtureDirectory = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("CompileFixtures/PublicGraphLeaksInternalService")
	// fixture build 자료를 함께 정리할 임시 directory
	let temporaryDirectory = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
	// SwiftPM build artifact 전용 scratch 경로
	let scratchDirectory = temporaryDirectory
		.appendingPathComponent("scratch")
	// compiler output 기록 file 경로
	let outputFileURL = temporaryDirectory
		.appendingPathComponent("compiler-output.log")
	try FileManager.default.createDirectory(
		at: temporaryDirectory,
		withIntermediateDirectories: true
	)
	defer {
		try? FileManager.default.removeItem(at: temporaryDirectory)
	}
	// compiler output file 생성 결과
	let createdOutputFile = FileManager.default.createFile(
		atPath: outputFileURL.path,
		contents: nil
	)
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
	// compiler output 기록 file 연결
	process.standardOutput = outputFileHandle
	process.standardError = outputFileHandle

	try process.run()
	process.waitUntilExit()
	try outputFileHandle.close()

	// access-control 오류 확인용 compiler output
	let output = String(
		data: try Data(contentsOf: outputFileURL),
		encoding: .utf8
	) ?? ""

	#expect(process.terminationStatus != 0)
	#expect(output.contains("property cannot be declared public because its type uses an internal type"))
	#expect(output.contains("InternalService"))
}
