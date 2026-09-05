//
//  CradleDiagramMaker.swift
//  CradleDiagramMaker
//
//  Created by opfic on 9/4/26.
//

import CradleDiagramMakerSupport
import Foundation

// SwiftPM Build Tool Plugin이 호출하는 Mermaid 산출물 생성 실행 파일
@main
struct CradleDiagramMakerCommand {
	// 명령행 입력을 검증하고 실제 산출물 디렉터리 출력
	static func main() {
		do {
			let command = try diagramMakerCommand(arguments: Array(CommandLine.arguments.dropFirst()))
			let outputs = try DiagramOutputWriter().write(request: command.request)
			print("Cradle Mermaid output: \(command.request.outputDirectoryURL.appendingPathComponent(command.request.moduleName).path)")
			for output in outputs {
				print(output.path)
			}
		} catch {
			// 실패 원인과 source 위치를 읽을 수 있는 도구 오류로 보고
			FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
			exit(EXIT_FAILURE)
		}
	}
}

// Build Tool Plugin 인자를 산출물 요청과 선언 output file로 변환
private func diagramMakerCommand(arguments: [String]) throws -> DiagramMakerCommand {
	guard 4 <= arguments.count,
		arguments[0] == "--module",
		arguments[2] == "--output",
		arguments[4...].allSatisfy({ !$0.hasPrefix("--") }) else {
		throw DiagramOutputError.invalidArguments
	}
	return DiagramMakerCommand(
		request: DiagramOutputRequest(
			moduleName: arguments[1],
			sourceURLs: arguments.dropFirst(4).map { URL(fileURLWithPath: $0) },
			outputDirectoryURL: URL(fileURLWithPath: arguments[3])
		)
	)
}

// Mermaid 생성 요청을 명령행 분석 결과로 보관
private struct DiagramMakerCommand {
	// source와 출력 디렉터리를 포함한 Mermaid 생성 요청
	let request: DiagramOutputRequest
}
