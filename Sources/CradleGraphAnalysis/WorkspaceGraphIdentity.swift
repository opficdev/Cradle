//
//  WorkspaceGraphIdentity.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

// workspace target의 표시 이름과 분리한 안정 식별자
package struct WorkspaceTargetID: Hashable, Comparable, Codable {
	// manifest가 지정한 target 식별자
	package let rawValue: String

	package init(_ rawValue: String) {
		self.rawValue = rawValue
	}

	package static func < (lhs: Self, rhs: Self) -> Bool {
		lhs.rawValue < rhs.rawValue
	}
}

// workspace 안의 명목 선언을 구별하는 target·lexical 경로 식별자
package struct WorkspaceDeclarationID: Hashable, Comparable, Codable {
	// 선언이 속한 workspace target
	package let targetID: WorkspaceTargetID
	// 바깥 선언부터 나열한 이름 경로
	package let lexicalPath: [String]

	package init(targetID: WorkspaceTargetID, lexicalPath: [String]) {
		self.targetID = targetID
		self.lexicalPath = lexicalPath
	}

	// Mermaid label과 진단에 사용할 lexical 이름
	package var lexicalName: String {
		lexicalPath.joined(separator: ".")
	}

	package static func < (lhs: Self, rhs: Self) -> Bool {
		if lhs.targetID != rhs.targetID {
			return lhs.targetID < rhs.targetID
		}
		return lhs.lexicalPath.lexicographicallyPrecedes(rhs.lexicalPath)
	}
}

// manifest root 기준의 source 위치
package struct WorkspaceSourceLocation: Hashable, Comparable, Codable {
	// source가 속한 target
	package let targetID: WorkspaceTargetID
	// manifest root 기준 source 경로
	package let path: String
	// source 파일의 UTF-8 offset
	package let utf8Offset: Int

	package init(targetID: WorkspaceTargetID, path: String, utf8Offset: Int) {
		self.targetID = targetID
		self.path = path
		self.utf8Offset = utf8Offset
	}

	package static func < (lhs: Self, rhs: Self) -> Bool {
		if lhs.targetID != rhs.targetID {
			return lhs.targetID < rhs.targetID
		}
		if lhs.path != rhs.path {
			return lhs.path < rhs.path
		}
		return lhs.utf8Offset < rhs.utf8Offset
	}
}

// source 파일이 속한 module과 직접 import 정보
package struct WorkspaceSourceContext: Hashable {
	// source target 식별자
	package let targetID: WorkspaceTargetID
	// 실제 Swift module 이름
	package let moduleName: String
	// manifest root 기준 source 경로
	package let path: String
	// manifest가 명시한 로컬 target dependency
	package let dependencyIDs: Set<WorkspaceTargetID>
	// source 파일이 직접 import한 module 이름
	package let importedModules: Set<String>

	package init(
		targetID: WorkspaceTargetID,
		moduleName: String,
		path: String,
		dependencyIDs: Set<WorkspaceTargetID>,
		importedModules: Set<String>
	) {
		self.targetID = targetID
		self.moduleName = moduleName
		self.path = path
		self.dependencyIDs = dependencyIDs
		self.importedModules = importedModules
	}
}
