//
//  SourceGraphSharedReferenceDiagnosticTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacrosTestSupport
import SwiftParser
import Testing
@testable import CradleMacros

// shared Factory가 source graph 저장 프로퍼티를 참조하면 거부하는지 확인
@Test
func sourceGraphMacroRejectsSharedFactorySourceReference() {
	assertMacroExpansion(
		"""
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph {
			@Provide(.shared)
			private func makeFeature() -> Feature {
				Feature(repository: appGraph.repository)
			}
		}
		""",
		expandedSource: """
		final class FeatureGraph {
			private func makeFeature() -> Feature {
				Feature(repository: appGraph.repository)
			}
		}
		""",
		diagnostics: [
			DiagnosticSpec(
				id: .init(domain: "Cradle", id: "sharedSourceReference"),
				message: "`@Provide(.shared)` Factory는 `appGraph` source graph를 참조할 수 없습니다.",
				line: 5,
				column: 23,
				highlights: ["appGraph"]
			)
		],
		macros: testMacros
	)
}

// source 저장 프로퍼티의 직접 참조 위치 탐색
@Test
func sourceGraphReferenceFindsUnshadowedSourceStorage() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { Feature(repository: appGraph.repository) }"
	)

	let reference = try #require(
		sourceGraphReference(in: factory, sourceNames: ["appGraph"])
	)
	#expect(reference.text == "appGraph")
}

// 명시적 self의 source 저장 프로퍼티 참조 위치 탐색
@Test
func sourceGraphReferenceFindsExplicitSelfSourceStorage() throws {
	let factory = try FunctionDeclSyntax(
		"""
		private func makeFeature() -> Feature {
			let appGraph = LocalGraph()
			return Feature(repository: self.appGraph.repository)
		}
		"""
	)

	let reference = try #require(
		sourceGraphReference(in: factory, sourceNames: ["appGraph"])
	)
	#expect(reference.text == "appGraph")
}

// closure가 bare capture한 source 저장 프로퍼티 참조 위치 탐색
@Test
func sourceGraphReferenceFindsBareSourceCapture() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let transform = { [appGraph] in appGraph.feature }; return transform() }"
	)

	let reference = try #require(
		sourceGraphReference(in: factory, sourceNames: ["appGraph"])
	)
	#expect(reference.text == "appGraph")
}

// Factory 매개변수와 같은 source 이름은 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresFactoryParameterShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature(appGraph: AppGraph) -> Feature { appGraph.feature }"
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}

// 지역 변수와 같은 source 이름은 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresLocalVariableShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let appGraph = LocalGraph(); return appGraph.feature }"
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}

// closure 매개변수와 capture 별칭의 동명 source 이름을 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresClosureBindingShadowing() throws {
	let factories = [
		"""
		private func makeFeature() -> Feature {
			let transform = { appGraph in appGraph.feature }
			return transform(LocalGraph())
		}
		""",
		"""
		private func makeFeature() -> Feature {
			let transform = { [appGraph = LocalGraph()] in appGraph.feature }
			return transform()
		}
		"""
	]

	try assertSourceGraphReferenceIsAbsent(in: factories)
}

// 제어 흐름 binding의 동명 source 이름을 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresControlFlowBindingShadowing() throws {
	let factories = [
		"""
		private func makeFeature() -> Feature {
			if let appGraph = Optional(LocalGraph()) { return appGraph.feature }
			return Feature()
		}
		""",
		"""
		private func makeFeature() -> Feature {
			guard let appGraph = Optional(LocalGraph()) else { return Feature() }
			return appGraph.feature
		}
		""",
		"""
		private func makeFeature() -> Feature {
			for appGraph in [LocalGraph()] { return appGraph.feature }
			return Feature()
		}
		""",
		"""
		private func makeFeature() -> Feature {
			while let appGraph = Optional(LocalGraph()) { return appGraph.feature }
			return Feature()
		}
		""",
		"""
		private func makeFeature() -> Feature {
			switch LocalGraph() { case let appGraph: return appGraph.feature }
		}
		""",
		"""
		private func makeFeature() -> Feature {
			do { throw LocalError() }
			catch let appGraph { return appGraph.feature }
		}
		"""
	]

	try assertSourceGraphReferenceIsAbsent(in: factories)
}

// 중첩 함수 매개변수와 동명인 source 이름을 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresNestedFunctionParameterShadowing() throws {
	let factory = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			func localFeature(appGraph: LocalGraph) -> Feature { appGraph.feature }
			return localFeature(LocalGraph())
		}
		"""
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}

// 중첩 함수가 source 저장 이름과 같아도 자기 참조를 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresNestedFunctionNameShadowing() throws {
	let factory = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			func appGraph() -> Feature { appGraph() }
			return appGraph()
		}
		"""
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}

// 선언보다 앞선 지역 함수 호출을 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferenceIgnoresForwardNestedFunctionShadowing() throws {
	let factory = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			let feature = appGraph()
			func appGraph() -> Feature { Feature() }
			return feature
		}
		"""
	)

	#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
}

// 문자열 Factory 선언의 source 참조 탐색용 구문 분석
private func sourceGraphReferenceFactory(_ source: String) throws -> FunctionDeclSyntax {
	let file = Parser.parse(source: source)
	return try #require(file.statements.first?.item.as(FunctionDeclSyntax.self))
}

// source 저장 프로퍼티와 동명인 지역 binding의 오진 여부 확인
private func assertSourceGraphReferenceIsAbsent(in sources: [String]) throws {
	for source in sources {
		let factory = try sourceGraphReferenceFactory(source)
		#expect(sourceGraphReference(in: factory, sourceNames: ["appGraph"]) == nil)
	}
}
