//
//  WorkspaceDiagramLoader.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/8/26.
//

import CradleGraphAnalysis
import Foundation
import SwiftParser
import SwiftSyntax

// manifest를 읽고 선택 target의 선언 색인을 만드는 loader
package struct WorkspaceDiagramLoader {
	package init() {}

	// 요청의 manifest와 source를 검증한 workspace 선언 색인 반환
	package func load(request: WorkspaceDiagramRequest) throws -> LoadedWorkspaceDiagram {
		let manifest = try loadManifest(at: request.manifestURL)
		try manifest.validate()
		guard request.view != .composition || !manifest.roots.isEmpty else {
			throw WorkspaceDiagramLoaderError.invalidManifest("composition 보기에는 roots가 하나 이상 필요합니다")
		}
		let selectedTargets = try selectedTargets(in: manifest)
		let descriptors = selectedTargets.map { target in
			WorkspaceTargetDescriptor(
				id: WorkspaceTargetID(target.id),
				moduleName: target.moduleName,
				dependencyIDs: Set(target.dependencies.map(WorkspaceTargetID.init))
			)
		}
		let collector = WorkspaceDeclarationCollector(targets: descriptors)
		let rootURL = try resolvedRootURL(for: manifest, manifestURL: request.manifestURL)
		let targetsByID = Dictionary(uniqueKeysWithValues: manifest.targets.map { ($0.id, $0) })
		for target in selectedTargets {
			try collectTarget(
				target,
				rootURL: rootURL,
				dependencyIDs: workspaceDependencyClosure(of: target.id, targets: targetsByID),
				collector: collector
			)
		}
		let index = collector.index()
		try validateUniqueGraphs(index.graphs)
		return LoadedWorkspaceDiagram(manifest: manifest, index: index)
	}

	// JSON manifest 해독과 형식 오류 변환
	private func loadManifest(at url: URL) throws -> WorkspaceDiagramManifest {
		do {
			let data = try Data(contentsOf: url)
			return try JSONDecoder().decode(WorkspaceDiagramManifest.self, from: data)
		} catch let error as WorkspaceDiagramManifestError {
			throw error
		} catch {
			throw WorkspaceDiagramLoaderError.invalidManifest("`\(url.path)`을 읽거나 해독할 수 없습니다: \(error.localizedDescription)")
		}
	}

	// manifest 기준 rootDirectory의 실제 경로 계산
	private func resolvedRootURL(for manifest: WorkspaceDiagramManifest, manifestURL: URL) throws -> URL {
		let rootURL = manifestURL
			.deletingLastPathComponent()
			.appendingPathComponent(manifest.rootDirectory)
			.standardizedFileURL
		var isDirectory: ObjCBool = false
		guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
			throw WorkspaceDiagramLoaderError.invalidManifest("rootDirectory를 찾을 수 없습니다: \(rootURL.path)")
		}
		return rootURL
	}

	// root target과 전이 dependency로 분석 target 선택
	private func selectedTargets(in manifest: WorkspaceDiagramManifest) throws -> [WorkspaceDiagramManifestTarget] {
		guard !manifest.roots.isEmpty else {
			return manifest.targets.sorted { $0.id < $1.id }
		}
		let targets = Dictionary(uniqueKeysWithValues: manifest.targets.map { ($0.id, $0) })
		var selected = Set<String>()
		var pending = manifest.roots.map(\.targetID)
		while let id = pending.popLast() {
			guard selected.insert(id).inserted else {
				continue
			}
			guard let target = targets[id] else {
				throw WorkspaceDiagramLoaderError.invalidManifest("root target `\(id)`를 찾을 수 없습니다")
			}
			pending += target.dependencies
		}
		return manifest.targets.filter { selected.contains($0.id) }.sorted { $0.id < $1.id }
	}

	// target source를 parser와 선언 collector에 전달
	private func collectTarget(
		_ target: WorkspaceDiagramManifestTarget,
		rootURL: URL,
		dependencyIDs: Set<WorkspaceTargetID>,
		collector: WorkspaceDeclarationCollector
	) throws {
		var paths = Set<String>()
		for path in target.sourceFiles.sorted() {
			let url = rootURL.appendingPathComponent(path).standardizedFileURL
			guard url.pathExtension == "swift" else {
				throw WorkspaceDiagramLoaderError.invalidManifest(
					"target `\(target.id)`의 sourceFiles는 Swift 파일이어야 합니다: \(path)"
				)
			}
			let resolvedPath = url.resolvingSymlinksInPath().path
			guard paths.insert(resolvedPath).inserted else {
				throw WorkspaceDiagramLoaderError.invalidManifest(
					"target `\(target.id)`에 중복된 source 파일이 있습니다: \(path)"
				)
			}
			let source: String
			do {
				source = try String(contentsOf: url, encoding: .utf8)
			} catch {
				throw WorkspaceDiagramLoaderError.invalidSource(url)
			}
			let sourceFile = Parser.parse(source: source)
			guard !sourceFile.hasError else {
				throw WorkspaceDiagramLoaderError.invalidSource(url)
			}
			let context = WorkspaceSourceContext(
				targetID: WorkspaceTargetID(target.id),
				moduleName: target.moduleName,
				path: path,
				dependencyIDs: dependencyIDs,
				importedModules: workspaceImportedModules(in: sourceFile)
			)
			collector.collect(sourceFile: sourceFile, context: context)
		}
	}

	// 같은 target 안의 중복 lexical graph를 source 위치와 함께 차단
	private func validateUniqueGraphs(_ graphs: [WorkspaceGraphDescriptor]) throws {
		let duplicates = Dictionary(grouping: graphs, by: \.id)
			.filter { 1 < $0.value.count }
			.sorted { $0.key < $1.key }
		guard let duplicate = duplicates.first else {
			return
		}
		let locations = duplicate.value.map(\.location).sorted().map { location in
			"\(location.path):\(location.utf8Offset)"
		}.joined(separator: ", ")
		throw WorkspaceDiagramLoaderError.invalidManifest(
			"중복된 workspace graph `\(duplicate.key.lexicalName)`을 찾았습니다: \(locations)"
		)
	}
}

// target이 직접 import할 수 있는 전이 로컬 dependency 집합
private func workspaceDependencyClosure(
	of targetID: String,
	targets: [String: WorkspaceDiagramManifestTarget]
) -> Set<WorkspaceTargetID> {
	var result = Set<WorkspaceTargetID>()
	var pending = targets[targetID]?.dependencies ?? []
	while let id = pending.popLast() {
		guard result.insert(WorkspaceTargetID(id)).inserted else { continue }
		pending += targets[id]?.dependencies ?? []
	}
	return result
}

// 해독한 manifest와 선택 source의 선언 색인
package struct LoadedWorkspaceDiagram {
	// 출력 경로에 사용할 검증된 manifest
	package let manifest: WorkspaceDiagramManifest
	// 선택 target의 선언 index
	package let index: WorkspaceDeclarationIndex

	package init(manifest: WorkspaceDiagramManifest, index: WorkspaceDeclarationIndex) {
		self.manifest = manifest
		self.index = index
	}
}

// manifest·source 로딩 중단 사유
package enum WorkspaceDiagramLoaderError: LocalizedError {
	case invalidManifest(String)
	case invalidSource(URL)

	package var errorDescription: String? {
		switch self {
		case let .invalidManifest(message):
			return "workspace Mermaid 분석을 시작할 수 없습니다: \(message)"
		case let .invalidSource(url):
			return "workspace Mermaid 분석을 할 수 없는 Swift source입니다: \(url.path)"
		}
	}
}

// source 파일의 직접 import module 이름 수집
private func workspaceImportedModules(in sourceFile: SourceFileSyntax) -> Set<String> {
	let collector = WorkspaceImportCollector()
	collector.walk(sourceFile)
	return collector.modules
}

// import declaration의 access path 수집기
private final class WorkspaceImportCollector: SyntaxVisitor {
	// source 파일이 직접 import한 module
	private(set) var modules = Set<String>()

	init() {
		super.init(viewMode: .sourceAccurate)
	}

	override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
		let module = node.path.trimmedDescription.split(separator: ".").first.map(String.init)
		if let module, !module.isEmpty {
			modules.insert(module)
		}
		return .skipChildren
	}
}
