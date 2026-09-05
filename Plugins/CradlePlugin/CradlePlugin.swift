//
//  CradlePlugin.swift
//  CradlePlugin
//
//  Created by opfic on 9/4/26.
//

import Foundation
import PackagePlugin

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin
#endif

// target source의 DependencyGraph Mermaid `.mmd` 산출물을 만드는 Build Tool Plugin
@main
struct CradlePlugin: BuildToolPlugin {
	// 현재 SwiftPM source target을 단위로 Mermaid 생성 명령 구성
	func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
		guard let sourceTarget = target as? SwiftSourceModuleTarget else {
			return []
		}
		let tool = try context.tool(named: "CradleDiagramMaker")
		let sourcePaths = sourceTarget.sourceFiles
			.filter { $0.type == .source }
			.map(\.url)
			.sorted { $0.path < $1.path }
		return mermaidBuildCommands(
			toolURL: tool.url,
			pluginWorkDirectoryURL: context.pluginWorkDirectoryURL,
			moduleName: sourceTarget.moduleName,
			sourceURLs: sourcePaths
		)
	}
}

#if canImport(XcodeProjectPlugin)
// Xcode 프로젝트 target의 Mermaid 생성 진입점
extension CradlePlugin: XcodeBuildToolPlugin {
	// 현재 Xcode target source를 단위로 Mermaid 생성 명령 구성
	func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
		let tool = try context.tool(named: "CradleDiagramMaker")
		let sourceURLs = target.inputFiles
			.map(\.url)
			.filter { $0.pathExtension == "swift" }
			.sorted { $0.path < $1.path }
		// 표시 이름을 Swift module로 해석하지 않고 단일 출력 경로 요소로 변환
		let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
		let namespace = target.displayName.addingPercentEncoding(withAllowedCharacters: allowed) ?? target.id
		return mermaidBuildCommands(
			toolURL: tool.url,
			pluginWorkDirectoryURL: context.pluginWorkDirectoryURL,
			moduleName: namespace,
			sourceURLs: sourceURLs
		)
	}
}
#endif

// SwiftPM·Xcode target의 입력 변경과 반복 빌드에 적용할 Mermaid 명령 구성
private func mermaidBuildCommands(
	toolURL: URL,
	pluginWorkDirectoryURL: URL,
	moduleName: String,
	sourceURLs: [URL]
) -> [Command] {
	let outputDirectory = pluginWorkDirectoryURL.appendingPathComponent("CradleDiagrams")
	let arguments = [
		"--module", moduleName,
		"--output", outputDirectory.path
	]
		+ sourceURLs.map(\.path)

	return [
		// `.mmd`를 resource로 등록하지 않고 매 빌드에서 기존 파일 정리까지 수행
		.buildCommand(
			displayName: "Cradle Mermaid diagrams",
			executable: toolURL,
			arguments: arguments,
			inputFiles: sourceURLs,
			outputFiles: []
		)
	]
}
