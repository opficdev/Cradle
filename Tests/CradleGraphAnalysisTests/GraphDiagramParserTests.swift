//
//  GraphDiagramParserTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/4/26.
//

import SwiftParser
import Testing
@testable import CradleGraphAnalysis

// module 한정 graph만 인식하고 다른 module의 동명 attribute는 제외
@Test
func graphDiagramsRecognizesQualifiedCradleGraph() {
	let source = Parser.parse(source: """
	@Cradle.DependencyGraph final class AppGraph {}
	@Cradle.DependencyGraph(diagram: false) final class HiddenGraph {}
	@Other.DependencyGraph final class UnrelatedGraph {}
	""")
	#expect(graphDiagrams(in: source).map(\.lexicalName) == ["AppGraph"])
}

// 프로퍼티 accessor와 initializer 내부의 지역 Factory 제외
@Test
func graphDiagramsExcludesIndirectProviders() {
	let source = Parser.parse(source: """
	@DependencyGraph final class AppGraph {
		var value: Int {
			@Provide func nested() -> Nested { Nested() }
			return 0
		}
		init() { @Provide func nested() -> Nested { Nested() } }
		@Provide private func direct() -> Direct { Direct() }
	}
	""")
	#expect(graphDiagrams(in: source)[0].providers.map(\.factoryName) == ["direct"])
}

// source graph·provider·수명·의존성 구문 수집 확인
@Test
func graphDiagramsCollectsGraphRelationships() {
	let sourceFile = Parser.parse(
		source: """
		@DependencyGraph(sources: [SessionGraph.self])
		final class AppGraph {
			@Provide(.shared)
			private func makeRepository() -> Repository {
				Repository(session: sessionGraph.session)
			}

		@Provide(.transient)
		private func makeFeature(repository: Repository) -> Feature {
			Feature(repository: repository)
		}

		@Provide(.transient)
		private func makeProfile(@External token: Token) -> Profile {
			Profile(token: token)
		}
		}
		"""
	)

	let diagram = graphDiagrams(in: sourceFile)

	#expect(diagram.map(\.lexicalName) == ["AppGraph"])
	#expect(diagram[0].sources.map(\.name) == ["sessionGraph"])
	#expect(diagram[0].providers.map(\.factoryName) == ["makeRepository", "makeFeature"])
	#expect(diagram[0].providers.map(\.lifetime) == [.shared, .transient])
	#expect(diagram[0].providers[0].sourceNames == ["sessionGraph"])
	#expect(diagram[0].providers[1].dependencyIdentities.map(\.canonicalText) == ["Repository"])
}

// `@External` Factory를 node와 연결에서 제외하고 본문 없는 일반 Factory는 포함하는지 확인
@Test
func graphDiagramsExcludesExternalFactoryAndIncludesBodylessProvider() {
	let sourceFile = Parser.parse(
		source: """
		@DependencyGraph
		final class AppGraph {
			@Provide
			private func makeRepository() -> Repository

			@Provide(.transient)
			private func makeProfile(@Cradle.External id: UserID) -> Profile { Profile(id: id) }
		}
		"""
	)

	let diagram = graphDiagrams(in: sourceFile)

	#expect(diagram[0].providers.map(\.factoryName) == ["makeRepository"])
	#expect(diagram[0].providers[0].typeName == "Repository")
}

// 중첩 선언의 lexical type 경로를 산출물 identity에 보존하는지 확인
@Test
func graphDiagramsPreservesNestedLexicalTypePath() {
	let sourceFile = Parser.parse(
		source: """
		enum Composition {
			struct Feature {
				@DependencyGraph
				final class AppGraph {}
			}
		}
		"""
	)

	#expect(graphDiagrams(in: sourceFile).map(\.lexicalName) == ["Composition.Feature.AppGraph"])
}

// extension 대상 type 경로로 같은 graph 이름을 구별하는지 확인
@Test
func graphDiagramsPreservesExtensionLexicalTypePath() {
	let sourceFile = Parser.parse(
		source: """
		extension FeatureA {
			@DependencyGraph
			final class AppGraph {}
		}

		extension FeatureB {
			@DependencyGraph
			final class AppGraph {}
		}
		"""
	)

	#expect(graphDiagrams(in: sourceFile).map(\.lexicalName) == ["FeatureA.AppGraph", "FeatureB.AppGraph"])
}

// `diagram: false` graph는 분석 대상에서 제외하는지 확인
@Test
func graphDiagramsSkipsDisabledGraph() {
	let sourceFile = Parser.parse(
		source: """
		@DependencyGraph(diagram: false)
		final class DisabledGraph {}
		"""
	)

	#expect(graphDiagrams(in: sourceFile).isEmpty)
}

// 실제 build condition을 평가하지 않고 모든 `#if` 절을 수집하는지 확인
@Test
func graphDiagramsCollectsEveryConditionalCompilationClause() {
	let sourceFile = Parser.parse(
		source: """
		#if DEBUG
		@DependencyGraph
		final class AppGraph {
			@Provide
			private func makeDebugFeature() -> Feature { Feature() }
		}
		#else
		@DependencyGraph
		final class AppGraph {
			@Provide(.transient)
			private func makeReleaseFeature() -> Feature { Feature() }
		}
		#endif
		"""
	)

	let diagrams = graphDiagrams(in: sourceFile)

	#expect(diagrams.map(\.lexicalName) == ["AppGraph", "AppGraph"])
	#expect(diagrams.map { $0.providers[0].factoryName } == ["makeDebugFeature", "makeReleaseFeature"])
}
