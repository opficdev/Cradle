//
//  TargetGraphDiagram.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/5/26.
//

// target의 graph를 한 번씩 정렬하고 source 선언을 연결하는 집합
package struct TargetGraphDiagram {
	// 파일·선언 순서와 무관한 graph 순서
	package let diagrams: [GraphDiagram]
	// 정확한 lexical 경로에 대응하는 graph anchor
	private let anchors: [String: String]
	// 제외 graph가 바깥 범위의 동명 graph를 가리는 경로
	private let excludedNames: Set<String>

	// 중복 lexical 경로 검증을 마친 분석 모델로 집합 구성
	package init(diagrams: [GraphDiagram], excludedNames: Set<String> = []) {
		self.diagrams = diagrams.sorted { $0.lexicalName < $1.lexicalName }
		// 다른 조건부 절에 활성 선언이 있으면 동일 경로의 graph는 포함
		self.excludedNames = excludedNames.subtracting(diagrams.map(\.lexicalName))
		anchors = Dictionary(uniqueKeysWithValues: self.diagrams.enumerated().map { index, diagram in
			(diagram.lexicalName, "graph\(index)_root")
		})
	}

	// 의미 분석 없이 바깥 lexical scope의 정확한 source 이름만 연결
	package func anchor(for source: GraphDiagramSource, in diagram: GraphDiagram) -> String? {
		let name = source.identity.canonicalText
		if name.contains(".") {
			return excludedNames.contains(name) ? nil : anchors[name]
		}
		var scope = diagram.lexicalName.split(separator: ".").dropLast().map(String.init)
		while !scope.isEmpty {
			let candidate = (scope + [name]).joined(separator: ".")
			if excludedNames.contains(candidate) { return nil }
			if let anchor = anchors[candidate] {
				return anchor
			}
			scope.removeLast()
		}
		return excludedNames.contains(name) ? nil : anchors[name]
	}
}
