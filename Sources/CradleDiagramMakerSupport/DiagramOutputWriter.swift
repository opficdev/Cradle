//
//  DiagramOutputWriter.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/4/26.
//

import Foundation
import CradleGraphAnalysis
import SwiftParser

// CradleDiagramMaker의 입력 source와 산출물 디렉터리
package struct DiagramOutputRequest {
	package let moduleName: String
	package let sourceURLs: [URL]
	package let outputDirectoryURL: URL

	package init(moduleName: String, sourceURLs: [URL], outputDirectoryURL: URL) {
		self.moduleName = moduleName
		self.sourceURLs = sourceURLs
		self.outputDirectoryURL = outputDirectoryURL
	}
}

// Mermaid `.mmd` 산출물 생성 중단 사유
package enum DiagramOutputError: LocalizedError {
	case duplicateLexicalGraph(name: String, locations: [DiagramSourceLocation])
	case duplicateSourceAccessor(graph: String, name: String, types: [String])
	case invalidModuleName(String)
	case invalidSource(URL)
	case invalidArguments

	package var errorDescription: String? {
		switch self {
		case let .duplicateLexicalGraph(name, locations):
			let paths = locations.map(\.description).joined(separator: ", ")
			return "중복된 DependencyGraph lexical 이름 `\(name)`을 찾았습니다: \(paths)"
		case let .duplicateSourceAccessor(graph, name, types):
			return "`\(graph)`에서 중복된 source accessor `\(name)`을 찾았습니다: \(types.joined(separator: ", "))"
		case let .invalidModuleName(name):
			return "Mermaid 출력 이름은 비어 있지 않은 단일 경로 요소여야 합니다: \(name)"
		case let .invalidSource(url):
			return "DependencyGraph Mermaid 분석을 할 수 없는 Swift source입니다: \(url.path)"
		case .invalidArguments:
			return "사용법: CradleDiagramMaker --module <module> --output <directory> <source>..."
		}
	}
}

// source graph 선언 위치를 보존한 Mermaid 산출물 충돌 정보
package struct DiagramSourceLocation: Hashable, CustomStringConvertible {
	package let sourceURL: URL
	package let offset: Int

	package var description: String {
		"\(sourceURL.path):\(offset)"
	}
}

// 생성 전 전체 분석을 끝내고 tool 소유 `.mmd` 파일만 갱신하는 writer
package struct DiagramOutputWriter {
	package init() {}

	@discardableResult
	package func write(request: DiagramOutputRequest) throws -> [URL] {
		try validateModuleName(request.moduleName)
		let collected = try collectDiagrams(from: request.sourceURLs)
		let diagrams = collected.diagrams
		try validateUniqueLexicalNames(diagrams)
		try validateUniqueSourceAccessors(diagrams)
		let directory = request.outputDirectoryURL.appendingPathComponent(request.moduleName)
		let output = directory.appendingPathComponent("DependencyGraph.mmd")
		let outputs = diagrams.isEmpty ? [] : [output]
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		if !diagrams.isEmpty {
			try writeIfChanged(content: mermaidDiagram(
				for: diagrams.map(\.diagram), excludedNames: collected.excludedNames), to: output)
		}
		try removeStaleOutputs(
			in: directory,
			keeping: Set(outputs.map { $0.resolvingSymlinksInPath().path })
		)
		return outputs
	}

	// SwiftPM module 또는 Xcode target 이름의 경로 이탈 차단
	private func validateModuleName(_ moduleName: String) throws {
		guard !moduleName.isEmpty, moduleName != ".", moduleName != "..",
			!moduleName.contains("/"), !moduleName.contains("\\"), !moduleName.contains("\0") else {
			throw DiagramOutputError.invalidModuleName(moduleName)
		}
	}

	private func validateUniqueSourceAccessors(_ diagrams: [CollectedDiagram]) throws {
		for diagram in diagrams {
			let duplicates = Dictionary(grouping: diagram.diagram.sources, by: \.name)
				.filter { 1 < $0.value.count }
				.sorted { $0.key < $1.key }
			guard let duplicate = duplicates.first else {
				continue
			}
			throw DiagramOutputError.duplicateSourceAccessor(
				graph: diagram.diagram.lexicalName,
				name: duplicate.key,
				types: duplicate.value.map(\.typeName).sorted()
			)
		}
	}

	private func collectDiagrams(from sourceURLs: [URL]) throws -> (
		diagrams: [CollectedDiagram], excludedNames: Set<String>
	) {
		var diagrams = [CollectedDiagram]()
		var excludedNames = Set<String>()
		for url in sourceURLs.sorted(by: { $0.path < $1.path }) {
			let source = try String(contentsOf: url, encoding: .utf8)
			let sourceFile = Parser.parse(source: source)
			guard !sourceFile.hasError else {
				throw DiagramOutputError.invalidSource(url)
			}
			let collection = graphDiagramCollection(in: sourceFile)
			excludedNames.formUnion(collection.excludedNames)
			diagrams += collection.diagrams.map { diagram in
				CollectedDiagram(
					diagram: diagram,
					location: DiagramSourceLocation(sourceURL: url, offset: diagram.sourceOffset)
				)
			}
		}
		return (diagrams, excludedNames)
	}

	private func validateUniqueLexicalNames(_ diagrams: [CollectedDiagram]) throws {
		let duplicates = Dictionary(grouping: diagrams, by: { $0.diagram.lexicalName })
			.filter { 1 < $0.value.count }
			.sorted { $0.key < $1.key }
		guard let duplicate = duplicates.first else {
			return
		}
		throw DiagramOutputError.duplicateLexicalGraph(
			name: duplicate.key,
			locations: duplicate.value.map(\.location)
		)
	}

	private func writeIfChanged(content: String, to url: URL) throws {
		let data = Data(content.utf8)
		if let existing = try? Data(contentsOf: url), existing == data {
			return
		}
		try data.write(to: url, options: .atomic)
	}

	private func removeStaleOutputs(in directory: URL, keeping paths: Set<String>) throws {
		let contents = try FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: nil
		)
		for url in contents where url.pathExtension == "mmd"
			&& !paths.contains(url.resolvingSymlinksInPath().path) {
			try FileManager.default.removeItem(at: url)
		}
	}
}

// source 분석 결과와 충돌 위치를 함께 보관
private struct CollectedDiagram {
	// Mermaid 산출물로 변환할 정적 graph 모델
	let diagram: GraphDiagram
	// 중복 graph 진단에 사용할 원본 source 위치
	let location: DiagramSourceLocation
}
