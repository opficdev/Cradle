//
//  SourceGraphReferenceTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 9/2/26.
//

import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import Testing
@testable import CradleMacros

// shared Factory의 모든 source 저장 프로퍼티 참조를 수집하는지 확인
@Test
func sourceGraphReferencesCollectAllUnshadowedSourceStorage() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { Feature(repository: appGraph.repository, session: sessionGraph.session) }"
	)

	let references = sourceGraphReferences(
		in: factory,
		sourceNames: ["appGraph", "sessionGraph"]
	)

	#expect(references.sourceNames == ["appGraph", "sessionGraph"])
	#expect(references.bare.count == 2)
}

// 명시적 self의 source 저장 프로퍼티 참조를 수집하는지 확인
@Test
func sourceGraphReferencesCollectExplicitSelfSourceStorage() throws {
	let factory = try FunctionDeclSyntax(
		"""
		private func makeFeature() -> Feature {
			let appGraph = LocalGraph()
			return Feature(repository: self.appGraph.repository)
		}
		"""
	)

	let references = sourceGraphReferences(in: factory, sourceNames: ["appGraph"])

	#expect(references.sourceNames == ["appGraph"])
	#expect(references.explicitSelf.count == 1)
}

// bare closure capture source 저장 프로퍼티 참조를 수집하는지 확인
@Test
func sourceGraphReferencesCollectBareSourceCapture() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let transform = { [appGraph] in appGraph.feature }; return transform() }"
	)

	let references = sourceGraphReferences(in: factory, sourceNames: ["appGraph"])

	#expect(references.sourceNames == ["appGraph"])
	#expect(references.bareCapture.count == 1)
}

// source 참조를 shared helper 매개변수와 capture initializer로 바꾸는지 확인
@Test
func sourceGraphReferencesRewriteSharedFactoryBody() throws {
	let factory = try FunctionDeclSyntax(
		"""
		private func makeFeature() -> Feature {
			let value = appGraph.feature
			let transform = { [sessionGraph] in self.appGraph.feature + sessionGraph.feature }
			return Feature(value: value + transform())
		}
		"""
	)
	let references = sourceGraphReferences(
		in: factory,
		sourceNames: ["appGraph", "sessionGraph"]
	)
	let body = try #require(factory.body)
	let rewritten = rewrittenSourceGraphFactoryBody(
		body,
		references: references,
		parameterNames: ["appGraph": "sourceAppGraph", "sessionGraph": "sourceSessionGraph"]
	)

	#expect(rewritten.trimmedDescription.contains("sourceAppGraph.feature"))
	#expect(rewritten.trimmedDescription.contains("[sessionGraph=sourceSessionGraph]"))
	#expect(rewritten.trimmedDescription.contains("sessionGraph.feature"))
}

// source graph를 직접 읽는 shared Factory를 진단 없이 확장하는지 확인
@Test
func sourceGraphMacroAllowsSharedFactorySourceReference() throws {
	let file = Parser.parse(
		source: """
		@DependencyGraph(sources: [AppGraph.self])
		final class FeatureGraph {
			@Provide(.shared)
			private func makeFeature() -> Feature {
				Feature(repository: appGraph.repository)
			}
		}
		"""
	)
	let graph = try #require(file.statements.first?.item.as(ClassDeclSyntax.self))
	let attribute = try #require(graph.attributes.first?.as(AttributeSyntax.self))
	let context = BasicMacroExpansionContext(sourceFiles: [
		file: .init(moduleName: "Fixture", fullFilePath: "/Fixture.swift")
	])

	let declarations = try DependencyGraphMacro.expansion(
		of: attribute,
		providingMembersOf: graph,
		conformingTo: [],
		in: context
	)
	let source = declarations.map(\.trimmedDescription).joined(separator: "\n")

	#expect(context.diagnostics.isEmpty)
	#expect(source.contains("AppGraph"))
	#expect(source.contains("private let"))
	#expect(source.contains("repository"))
}

// Factory 매개변수와 같은 source 이름은 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreFactoryParameterShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature(appGraph: AppGraph) -> Feature { appGraph.feature }"
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// 지역 변수와 같은 source 이름은 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreLocalVariableShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let appGraph = LocalGraph(); return appGraph.feature }"
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// 같은 선언의 앞 binding이 뒤 initializer에서 source 이름을 가리는지 확인
@Test
func sourceGraphReferencesIgnoreEarlierLocalBindingInSameDeclaration() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let appGraph = LocalGraph(), feature = appGraph.feature; return feature }"
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// 지역 property wrapper 인자의 source 참조를 수집하는지 확인
@Test
func sourceGraphReferencesCollectLocalWrapperArgument() throws {
	let factory = try FunctionDeclSyntax(
		"""
		private func makeFeature() -> Feature {
			@Wrapper(extra: appGraph.feature) var feature = Feature()
			return feature
		}
		"""
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames == ["appGraph"])
}

// 지역 observer 본문에서는 이미 선언한 binding이 source 이름을 가리는지 확인
@Test
func sourceGraphReferencesIgnoreLocalObserverBindingShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"""
		private func makeFeature() -> Feature {
			var appGraph = LocalGraph() {
				didSet { _ = appGraph.feature }
			}
			return Feature()
		}
		"""
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// closure 매개변수와 capture 별칭의 동명 source 이름을 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreClosureBindingShadowing() throws {
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

	try assertSourceGraphReferencesAreAbsent(in: factories)
}

// 제어 흐름 binding의 동명 source 이름을 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreControlFlowBindingShadowing() throws {
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

	try assertSourceGraphReferencesAreAbsent(in: factories)
}

// guard 조건 binding의 후속 조건·else·성공 경로 scope를 구분하는지 확인
@Test
func sourceGraphReferencesRespectGuardConditionBindingScopes() throws {
	let chainedBinding = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			guard let appGraph = Optional(LocalGraph()), appGraph.isReady else { return Feature() }
			return appGraph.feature
		}
		"""
	)
	let elseSourceReference = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			guard let localGraph = Optional(LocalGraph()), localGraph.isReady else { return appGraph.feature }
			return localGraph.feature
		}
		"""
	)

	#expect(sourceGraphReferences(in: chainedBinding, sourceNames: ["appGraph"]).sourceNames.isEmpty)
	#expect(sourceGraphReferences(in: elseSourceReference, sourceNames: ["appGraph"]).sourceNames == ["appGraph"])
}

// 중첩 함수 매개변수와 동명인 source 이름을 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreNestedFunctionParameterShadowing() throws {
	let factory = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			func localFeature(appGraph: LocalGraph) -> Feature { appGraph.feature }
			return localFeature(LocalGraph())
		}
		"""
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// 중첩 함수가 source 저장 이름과 같아도 자기 참조를 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreNestedFunctionNameShadowing() throws {
	let factory = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			func appGraph() -> Feature { appGraph() }
			return appGraph()
		}
		"""
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// 선언보다 앞선 지역 함수 호출을 source 저장 프로퍼티로 보지 않는지 확인
@Test
func sourceGraphReferencesIgnoreForwardNestedFunctionShadowing() throws {
	let factory = try sourceGraphReferenceFactory(
		"""
		private func makeFeature() -> Feature {
			let feature = appGraph()
			func appGraph() -> Feature { Feature() }
			return feature
		}
		"""
	)

	#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}

// 문자열 Factory 선언의 source 참조 탐색용 구문 분석
private func sourceGraphReferenceFactory(_ source: String) throws -> FunctionDeclSyntax {
	let file = Parser.parse(source: source)
	return try #require(file.statements.first?.item.as(FunctionDeclSyntax.self))
}

// source 저장 프로퍼티와 동명인 지역 binding의 오진 여부 확인
private func assertSourceGraphReferencesAreAbsent(in sources: [String]) throws {
	for source in sources {
		let factory = try sourceGraphReferenceFactory(source)
		#expect(sourceGraphReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
	}
}
