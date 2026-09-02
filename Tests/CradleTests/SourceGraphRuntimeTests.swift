//
//  SourceGraphRuntimeTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import Cradle
import Testing

// source graph가 shared로 보관할 repository
final class SourceGraphRepository {}

// source graph가 shared로 보관할 session
final class SourceGraphSession {}

// source graph가 transient로 만들 요청 식별자
struct SourceGraphRequestIdentifier {
	let value: Int
}

// source graph 자동 초기화 확인용 약한 참조 대상
protocol SourceGraphAutomaticDelegate: AnyObject {}

// 기본 initializer를 제공하는 source graph property wrapper
@propertyWrapper
struct SourceGraphDefaultValue<Value> {
	var wrappedValue: Value

	init() where Value == Int {
		wrappedValue = 0
	}
}

// 자동 초기화 graph가 받을 source graph
@DependencyGraph
final class SourceGraphAutomaticInitializerSource {}

// Optional var와 property wrapper를 보유한 source graph
@DependencyGraph(sources: [SourceGraphAutomaticInitializerSource.self])
final class SourceGraphAutomaticInitializerGraph {
	weak var delegate: (any SourceGraphAutomaticDelegate)?
	@SourceGraphDefaultValue var count: Int
}

// 조합 graph가 source 값으로 만들 결과
struct SourceGraphFeature {
	let repository: SourceGraphRepository
	let session: SourceGraphSession
	let requestIdentifier: Int
}

// repository와 요청 식별자를 제공할 source graph
@DependencyGraph
final class SourceGraphAppGraph {
	private var requestCount = 0

	@Provide(.shared)
	private func makeRepository() -> SourceGraphRepository {
		SourceGraphRepository()
	}

	@Provide
	private func makeRequestIdentifier() -> SourceGraphRequestIdentifier {
		requestCount += 1
		return SourceGraphRequestIdentifier(value: requestCount)
	}
}

// session을 제공할 source graph
@DependencyGraph
final class SourceGraphSessionGraph {
	@Provide(.shared)
	private func makeSession() -> SourceGraphSession {
		SourceGraphSession()
	}
}

// 두 source graph의 접근자를 직접 조합할 graph
@DependencyGraph(sources: [SourceGraphSessionGraph.self, SourceGraphAppGraph.self])
final class SourceGraphFeatureGraph {
	@Provide
	private func makeFeature() -> SourceGraphFeature {
		SourceGraphFeature(
			repository: sourceGraphAppGraph.sourceGraphRepository,
			session: sourceGraphSessionGraph.sourceGraphSession,
			requestIdentifier: sourceGraphAppGraph.sourceGraphRequestIdentifier.value
		)
	}
}

// source graph의 shared 값은 조합 graph 접근마다 같은 identity를 유지하는지 확인
@Test
func sourceGraphCompositionUsesSourceSharedValues() {
	let appGraph = SourceGraphAppGraph()
	let sessionGraph = SourceGraphSessionGraph()
	let graph = SourceGraphFeatureGraph(
		sourceGraphAppGraph: appGraph,
		sourceGraphSessionGraph: sessionGraph
	)
	let first = graph.sourceGraphFeature
	let second = graph.sourceGraphFeature

	#expect(first.repository === second.repository)
	#expect(first.session === second.session)
}

// source graph의 transient 값은 조합 graph 접근마다 새로 만드는지 확인
@Test
func sourceGraphCompositionRecreatesSourceTransientValues() {
	let graph = SourceGraphFeatureGraph(
		sourceGraphAppGraph: SourceGraphAppGraph(),
		sourceGraphSessionGraph: SourceGraphSessionGraph()
	)

	#expect(graph.sourceGraphFeature.requestIdentifier == 1)
	#expect(graph.sourceGraphFeature.requestIdentifier == 2)
}

// 조합 graph가 source graph를 강하게 보관하는지 확인
@Test
func sourceGraphCompositionRetainsSources() {
	weak var observedAppGraph: SourceGraphAppGraph?
	weak var observedSessionGraph: SourceGraphSessionGraph?

	do {
		let appGraph = SourceGraphAppGraph()
		let sessionGraph = SourceGraphSessionGraph()
		observedAppGraph = appGraph
		observedSessionGraph = sessionGraph
		let graph = SourceGraphFeatureGraph(
			sourceGraphAppGraph: appGraph,
			sourceGraphSessionGraph: sessionGraph
		)

		withExtendedLifetime(graph) {
			#expect(observedAppGraph != nil)
			#expect(observedSessionGraph != nil)
		}
	}

	#expect(observedAppGraph == nil)
	#expect(observedSessionGraph == nil)
}

// Swift가 자동 초기화하는 저장 프로퍼티를 source initializer와 함께 허용하는지 확인
@Test
func sourceGraphCompositionAllowsAutomaticallyInitializedStoredProperties() {
	let graph = SourceGraphAutomaticInitializerGraph(
		sourceGraphAutomaticInitializerSource: SourceGraphAutomaticInitializerSource()
	)

	#expect(graph.delegate == nil)
	#expect(graph.count == 0)
}
