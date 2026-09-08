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
			switch command {
			case let .target(request):
				let outputs = try DiagramOutputWriter().write(request: request)
				print("Cradle Mermaid output: \(request.outputDirectoryURL.appendingPathComponent(request.moduleName).path)")
				for output in outputs {
					print(output.path)
				}
			case let .workspace(request):
				let outputs = try WorkspaceDiagramOutputWriter().write(request: request)
				print("Cradle workspace Mermaid output: \(request.outputDirectoryURL.path)")
				for output in outputs {
					print(output.path)
				}
			}
		} catch {
			// 실패 원인과 source 위치를 읽을 수 있는 도구 오류로 보고
			FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
			exit(EXIT_FAILURE)
		}
	}
}
