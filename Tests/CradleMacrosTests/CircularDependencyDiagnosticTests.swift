//
//  CircularDependencyDiagnosticTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntaxMacrosTestSupport
import Testing
@testable import CradleMacros

// 자기 순환부터 여러 후보까지 첫 경로와 관련 없는 접근자의 생성 차단 확인
@Test
func circularDependencyDiagnosticFindsFirstClosedPath() {
	assertCircularDependency(nodes: [("A", ["a"])], path: [0], closing: 0)
	assertCircularDependency(nodes: [("A", ["b"]), ("B", ["a"])], path: [0, 1], closing: 1)
	assertCircularDependency(
		nodes: [("A", ["b"]), ("B", ["c"]), ("C", ["a"])], path: [0, 1, 2], closing: 2
	)
	assertCircularDependency(
		nodes: [("Entry", ["a"]), ("A", ["b"]), ("B", ["a"])], path: [1, 2], closing: 2
	)
	assertCircularDependency(
		nodes: [("Unused", []), ("A", ["b"]), ("B", ["a"])], path: [1, 2], closing: 2
	)
	assertCircularDependency(
		nodes: [("A", ["b"]), ("B", ["a"]), ("C", ["d"]), ("D", ["c"])], path: [0, 1], closing: 1
	)
	assertCircularDependency(
		nodes: [("A", ["c", "b"]), ("B", ["a"]), ("C", ["a"])], path: [0, 2], closing: 2
	)
	assertCircularDependency(
		nodes: [("A", ["b", "c"]), ("B", ["a"]), ("C", ["a"])], path: [0, 1], closing: 1
	)
}

// Optional 프로토콜 매개변수도 즉시 생성하는 연결로 검사하는지 확인
@Test
func circularDependencyDiagnosticIncludesOptionalProtocolParameters() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func makeA(b: (any B)?) -> any A { fatalError() }
			@Provide
			private func makeB(a: any A) -> any B { fatalError() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func makeA(b: (any B)?) -> any A { fatalError() }
			private func makeB(a: any A) -> any B { fatalError() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "circularDependency"),
				message: "`a → b → a` 순환 의존성이 있습니다.",
				line: 6,
				column: 21,
				highlights: ["a"],
				notes: [
					NoteSpec(message: "`makeA` Factory의 등록입니다. 생성 접근자는 `a`입니다.", line: 3, column: 2),
					NoteSpec(message: "`makeB` Factory의 등록입니다. 생성 접근자는 `b`입니다.", line: 5, column: 2)
				]
			)
		],
		macros: testMacros
	)
}

// 여러 줄 선언·주석·백틱 이름에서 원본 매개변수와 등록 위치 보존 확인
@Test
func circularDependencyDiagnosticPreservesOriginalLocations() {
	assertMacroExpansion(
		"""
		@DependencyGraph
		final class Graph {
			@Provide
			private func `makeA`(
				other b: any Domain.`b`
			) -> any A { fatalError() }
			@Provide
			private func `makeB`(
				_ /* label */ `a`: any A
			) -> any Domain.`b` { fatalError() }
		}
		""",
		expandedSource: """
		final class Graph {
			private func `makeA`(
				other b: any Domain.`b`
			) -> any A { fatalError() }
			private func `makeB`(
				_ /* label */ `a`: any A
			) -> any Domain.`b` { fatalError() }
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "circularDependency"),
				message: "`a → b → a` 순환 의존성이 있습니다.",
				line: 9,
				column: 17,
				highlights: ["`a`"],
				notes: [
					NoteSpec(message: "`makeA` Factory의 등록입니다. 생성 접근자는 `a`입니다.", line: 3, column: 2),
					NoteSpec(message: "`makeB` Factory의 등록입니다. 생성 접근자는 `b`입니다.", line: 7, column: 2)
				]
			)
		],
		macros: testMacros
	)
}

// 경로와 Factory 이름에 관계없는 진단 식별자·심각도·인용 보존 확인
@Test(arguments: ["makeA", "`makeA`"])
func circularDependencyDiagnosticKeepsIdentifiersStable(factoryName: String) {
	// 오류 식별자와 심각도를 직접 확인할 메시지
	let diagnostic = CircularDependencyDiagnostic(accessorIdentifiers: ["a", "a"])
	// 보조 설명 식별자와 백틱 인용을 확인할 메시지
	let note = CircularDependencyProviderNote(factoryName: factoryName, accessorIdentifier: "a")
	#expect(diagnostic.diagnosticID == .init(domain: "Cradle", id: "circularDependency"))
	#expect(diagnostic.severity == .error)
	#expect(diagnostic.message == "`a → a` 순환 의존성이 있습니다.")
	#expect(note.noteID == .init(domain: "Cradle", id: "circularDependencyProvider"))
	#expect(note.message == "`makeA` Factory의 등록입니다. 생성 접근자는 `a`입니다.")
}

// 명시한 연결과 기대 경로로 선언·매개변수 순서의 첫 순환 검증
private func assertCircularDependency(
	nodes: [(name: String, dependencies: [String])],
	path: [Int],
	closing: Int
) {
	// 각 등록의 단순 Factory 선언
	let methods = nodes.map { node in
		// 연결 대상 이름을 매개변수로 배치한 선언
		let parameters = node.dependencies.map { "\($0): Any" }.joined(separator: ", ")
		return "\tprivate func make\(node.name)(\(parameters)) -> \(node.name) { fatalError() }"
	}
	// 원본 @Provide를 포함한 입력 클래스
	let source = "@DependencyGraph\nfinal class Graph {\n"
		+ methods.map { "\t@Provide\n\($0)" }.joined(separator: "\n") + "\n}"
	// 순환이 있으면 접근자를 하나도 추가하지 않는 기대 클래스
	let expanded = "final class Graph {\n" + methods.joined(separator: "\n") + "\n}"
	// 탐색 결과에서 계산하지 않고 호출자가 지정한 기대 경로
	let names = path.map { nodes[$0].name.lowercased() }
	// 닫는 연결의 첫 매개변수 토큰 시작 위치
	let column = "\tprivate func make\(nodes[closing].name)(".count + 1
	// 기대 경로의 각 원본 등록에 표시할 보조 설명
	let notes = path.map { index in
		NoteSpec(
			message: "`make\(nodes[index].name)` Factory의 등록입니다. "
				+ "생성 접근자는 `\(nodes[index].name.lowercased())`입니다.",
			line: 3 + index * 2,
			column: 2
		)
	}
	assertMacroExpansion(
		source,
		expandedSource: expanded,
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "circularDependency"),
				message: "`\((names + [names[0]]).joined(separator: " → "))` 순환 의존성이 있습니다.",
				line: 4 + closing * 2,
				column: column,
				highlights: [names[0]],
				notes: notes
			)
		],
		macros: testMacros
	)
}
