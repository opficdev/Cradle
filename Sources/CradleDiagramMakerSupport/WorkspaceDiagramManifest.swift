//
//  WorkspaceDiagramManifest.swift
//  CradleDiagramMakerSupport
//
//  Created by opfic on 9/8/26.
//

import Foundation

// workspace Mermaid 분석 입력의 JSON 계약
package struct WorkspaceDiagramManifest: Decodable {
	// 입력 형식 버전
	package let schemaVersion: Int
	// 산출물 하위 디렉터리 이름
	package let workspaceName: String
	// manifest 파일 기준 source 경로 root
	package let rootDirectory: String
	// 분석 target 목록
	package let targets: [WorkspaceDiagramManifestTarget]
	// composition 분석 시작 graph 목록
	package let roots: [WorkspaceDiagramManifestRoot]
	// 일반 조립 코드 분석 허용 type 목록
	package let compositionTypes: [WorkspaceDiagramManifestCompositionType]

	private enum CodingKeys: String, CaseIterable {
		case schemaVersion
		case workspaceName
		case rootDirectory
		case targets
		case roots
		case compositionTypes
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: WorkspaceDiagramCodingKey.self)
		try workspaceValidateKeys(container, allowed: CodingKeys.allCases.map(\.rawValue))
		schemaVersion = try container.decode(Int.self, forKey: WorkspaceDiagramCodingKey("schemaVersion"))
		workspaceName = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("workspaceName"))
		rootDirectory = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("rootDirectory"))
		targets = try container.decode([WorkspaceDiagramManifestTarget].self, forKey: WorkspaceDiagramCodingKey("targets"))
		roots = try container.decodeIfPresent(
			[WorkspaceDiagramManifestRoot].self,
			forKey: WorkspaceDiagramCodingKey("roots")
		) ?? []
		compositionTypes = try container.decodeIfPresent(
			[WorkspaceDiagramManifestCompositionType].self,
			forKey: WorkspaceDiagramCodingKey("compositionTypes")
		) ?? []
	}

	// JSON 해독 뒤 manifest 전체 계약 검증
	package func validate() throws {
		guard schemaVersion == 1 else {
			throw WorkspaceDiagramManifestError.invalid("schemaVersion은 1이어야 합니다: \(schemaVersion)")
		}
		try workspaceValidatePathComponent(workspaceName, field: "workspaceName")
		guard !rootDirectory.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("rootDirectory는 비어 있을 수 없습니다")
		}
		guard !targets.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("targets는 하나 이상 필요합니다")
		}
		for target in targets {
			try target.validate()
		}
		try workspaceValidateUnique(targets.map(\.id), field: "target id")
		try workspaceValidateUnique(targets.map(\.moduleName), field: "moduleName")
		let targetIDs = Set(targets.map(\.id))
		for target in targets {
			for dependency in target.dependencies where !targetIDs.contains(dependency) {
				throw WorkspaceDiagramManifestError.invalid(
					"target `\(target.id)`의 dependency `\(dependency)`를 찾을 수 없습니다"
				)
			}
			if target.dependencies.contains(target.id) {
				throw WorkspaceDiagramManifestError.invalid("target `\(target.id)`가 자신을 dependency로 가집니다")
			}
		}
		try workspaceValidateAcyclicTargets(targets)
		for root in roots {
			try root.validate(targetIDs: targetIDs)
		}
		try workspaceValidateUnique(
			roots.map { "\($0.targetID).\($0.graph)" },
			field: "root"
		)
		for compositionType in compositionTypes {
			try compositionType.validate(targetIDs: targetIDs)
		}
		try workspaceValidateUnique(
			compositionTypes.map { "\($0.targetID).\($0.type)" },
			field: "composition type"
		)
	}
}

// manifest target의 source·dependency 입력
package struct WorkspaceDiagramManifestTarget: Decodable {
	// target 식별자
	package let id: String
	// 실제 Swift module 이름
	package let moduleName: String
	// rootDirectory 기준 Swift source 목록
	package let sourceFiles: [String]
	// 분석 범위를 제한할 로컬 target dependency
	package let dependencies: [String]

	private enum CodingKeys: String, CaseIterable {
		case id
		case moduleName
		case sourceFiles
		case dependencies
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: WorkspaceDiagramCodingKey.self)
		try workspaceValidateKeys(container, allowed: CodingKeys.allCases.map(\.rawValue))
		id = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("id"))
		moduleName = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("moduleName"))
		sourceFiles = try container.decode([String].self, forKey: WorkspaceDiagramCodingKey("sourceFiles"))
		dependencies = try container.decodeIfPresent([String].self, forKey: WorkspaceDiagramCodingKey("dependencies")) ?? []
	}

	fileprivate func validate() throws {
		guard !id.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("target id는 비어 있을 수 없습니다")
		}
		guard !moduleName.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("target `\(id)`의 moduleName은 비어 있을 수 없습니다")
		}
		guard !sourceFiles.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("target `\(id)`의 sourceFiles는 하나 이상 필요합니다")
		}
		try workspaceValidateUnique(sourceFiles, field: "target `\(id)`의 sourceFiles")
	}
}

// composition 분석 시작 graph
package struct WorkspaceDiagramManifestRoot: Decodable {
	// root graph target
	package let targetID: String
	// target 안의 lexical graph 경로
	package let graph: String

	private enum CodingKeys: String, CaseIterable {
		case targetID
		case graph
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: WorkspaceDiagramCodingKey.self)
		try workspaceValidateKeys(container, allowed: CodingKeys.allCases.map(\.rawValue))
		targetID = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("targetID"))
		graph = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("graph"))
	}

	fileprivate func validate(targetIDs: Set<String>) throws {
		guard targetIDs.contains(targetID), !graph.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("유효하지 않은 root `\(targetID).\(graph)`입니다")
		}
	}
}

// 제한된 일반 조립 코드 분석 대상 type
package struct WorkspaceDiagramManifestCompositionType: Decodable {
	// type이 속한 target
	package let targetID: String
	// target 안의 lexical type 경로
	package let type: String

	private enum CodingKeys: String, CaseIterable {
		case targetID
		case type
	}

	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: WorkspaceDiagramCodingKey.self)
		try workspaceValidateKeys(container, allowed: CodingKeys.allCases.map(\.rawValue))
		targetID = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("targetID"))
		type = try container.decode(String.self, forKey: WorkspaceDiagramCodingKey("type"))
	}

	fileprivate func validate(targetIDs: Set<String>) throws {
		guard targetIDs.contains(targetID), !type.isEmpty else {
			throw WorkspaceDiagramManifestError.invalid("유효하지 않은 composition type `\(targetID).\(type)`입니다")
		}
	}
}

// manifest key의 엄격한 검증용 CodingKey
private struct WorkspaceDiagramCodingKey: CodingKey {
	let stringValue: String
	let intValue: Int?

	init(_ stringValue: String) {
		self.stringValue = stringValue
		intValue = nil
	}

	init?(stringValue: String) {
		self.init(stringValue)
	}

	init?(intValue: Int) {
		return nil
	}
}

// manifest 계약 위반 오류
package enum WorkspaceDiagramManifestError: LocalizedError {
	case invalid(String)

	package var errorDescription: String? {
		switch self {
		case let .invalid(message):
			return "workspace Mermaid manifest 오류: \(message)"
		}
	}
}

// 알려지지 않은 JSON key 거부
private func workspaceValidateKeys(
	_ container: KeyedDecodingContainer<WorkspaceDiagramCodingKey>,
	allowed: [String]
) throws {
	let unknown = Set(container.allKeys.map(\.stringValue)).subtracting(allowed).sorted()
	guard unknown.isEmpty else {
		throw WorkspaceDiagramManifestError.invalid("알 수 없는 key: \(unknown.joined(separator: ", "))")
	}
}

// workspaceName의 경로 이탈 차단
private func workspaceValidatePathComponent(_ value: String, field: String) throws {
	guard !value.isEmpty, value != ".", value != "..",
		!value.contains("/"), !value.contains("\\"), !value.contains("\0") else {
		throw WorkspaceDiagramManifestError.invalid("\(field)은 비어 있지 않은 단일 경로 요소여야 합니다: \(value)")
	}
}

// manifest 배열의 중복 값 차단
private func workspaceValidateUnique(_ values: [String], field: String) throws {
	let duplicates = Dictionary(grouping: values, by: { $0 })
		.filter { 1 < $0.value.count }
		.keys
		.sorted()
	guard duplicates.isEmpty else {
		throw WorkspaceDiagramManifestError.invalid("중복된 \(field): \(duplicates.joined(separator: ", "))")
	}
}

// target dependency 순환 차단
private func workspaceValidateAcyclicTargets(_ targets: [WorkspaceDiagramManifestTarget]) throws {
	let dependencies = Dictionary(uniqueKeysWithValues: targets.map { ($0.id, $0.dependencies) })
	var visiting = Set<String>()
	var visited = Set<String>()

	func visit(_ id: String) throws {
		if visited.contains(id) {
			return
		}
		guard visiting.insert(id).inserted else {
			throw WorkspaceDiagramManifestError.invalid("target dependency 순환: \(id)")
		}
		for dependency in dependencies[id] ?? [] {
			try visit(dependency)
		}
		visiting.remove(id)
		visited.insert(id)
	}

	for target in targets.sorted(by: { $0.id < $1.id }) {
		try visit(target.id)
	}
}
