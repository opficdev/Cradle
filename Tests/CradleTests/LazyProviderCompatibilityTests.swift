//
//  LazyProviderCompatibilityTests.swift
//  CradleTests
//
//  Created by opfic on 9/6/26.
//

import Cradle
import Testing

// source graph가 매번 생성할 lazy 입력 값
struct LazySourceInput {
	// source graph 생성 순번
	let sequence: Int
}

// lazy source 조합의 최초 접근 시점을 기록할 source graph
@DependencyGraph
final class LazySourceGraph {
	// source Factory 실행 횟수
	private(set) var count = 0

	// source graph가 매번 생성할 입력 값
	@Provide(.transient)
	private func makeLazySourceInput() -> LazySourceInput {
		count += 1
		return LazySourceInput(sequence: count)
	}
}

// source graph 결과를 lazy로 보관할 조합 graph
@DependencyGraph(sources: [LazySourceGraph.self])
final class LazySourceFeatureGraph {
	// source graph의 transient 결과를 최초 접근에 읽는 lazy Factory
	@Provide(.lazy)
	private func makeLazySourceInput() -> LazySourceInput {
		lazySourceGraph.lazySourceInput
	}
}

// source graph 결과를 override 가능한 lazy로 보관할 조합 graph
@DependencyGraph(sources: [LazySourceGraph.self], overrides: true)
final class LazyOverrideSourceFeatureGraph {
	// source graph의 transient 결과를 최초 접근에 읽는 원본 lazy Factory
	@Provide(.lazy)
	private func makeLazySourceInput() -> LazySourceInput {
		lazySourceGraph.lazySourceInput
	}
}

// lazy 반환 타입의 protocol 계약
protocol LazyRepository {}

// lazy protocol 반환 타입의 구현
final class LazyLiveRepository: LazyRepository {}

// lazy 반환 타입의 superclass 계약
class LazyRepositoryBase {}

// lazy superclass 반환 타입의 구현
final class LazyRepositorySubclass: LazyRepositoryBase {}

// bodyless lazy Factory가 생성할 concrete 값
final class LazyBodylessConfiguration {}

// lazy Factory의 원래 `#function` 문맥 확인용 graph
@DependencyGraph
final class LazyFunctionGraph {
	// 원래 Factory 문맥을 반환할 lazy 등록
	@Provide(.lazy)
	private func makeLazyFunctionIdentifier() -> String {
		#function
	}
}

// protocol·superclass·bodyless lazy Factory를 함께 확인할 graph
@DependencyGraph
final class LazyReturnTypeGraph {
	// protocol로 노출할 lazy 구현 생성
	@Provide(.lazy)
	private func makeLazyRepository() -> any LazyRepository {
		LazyLiveRepository()
	}

	// superclass로 노출할 lazy 구현 생성
	@Provide(.lazy)
	private func makeLazyRepositoryBase() -> LazyRepositoryBase {
		LazyRepositorySubclass()
	}

	// 기본 initializer를 사용할 bodyless lazy Factory
	@Provide(.lazy)
	private func makeLazyBodylessConfiguration() -> LazyBodylessConfiguration
}

// actor graph가 lazy로 보관할 Sendable 참조 값
final class LazyActorService: Sendable {
	// actor 내부에서 기록한 생성 순번
	let sequence: Int

	// 생성 순번 보관
	init(sequence: Int) {
		self.sequence = sequence
	}
}

// actor 격리 안에서 lazy Factory를 평가할 graph
@DependencyGraph
actor LazyActorGraph {
	// actor 격리 생성 순번
	private var count = 0

	// actor 상태를 최초 접근에 읽는 lazy Factory
	@Provide(.lazy)
	private func makeLazyActorService() -> LazyActorService {
		count += 1
		return LazyActorService(sequence: count)
	}
}

// actor 격리 안에서 override 가능한 lazy Factory를 평가할 graph
@DependencyGraph(overrides: true)
actor LazyOverrideActorGraph {
	// 원본 lazy actor 결과 생성
	@Provide(.lazy)
	private func makeLazyActorService() -> LazyActorService {
		LazyActorService(sequence: 2)
	}
}

// MainActor graph가 lazy로 보관할 참조 값
final class LazyMainActorService {}

// MainActor 격리 안에서 lazy Factory를 평가할 graph
@MainActor
@DependencyGraph
final class LazyMainActorGraph {
	// MainActor Factory 실행 횟수
	private var count = 0

	// MainActor 상태를 최초 접근에 읽는 lazy Factory
	@Provide(.lazy)
	private func makeLazyMainActorService() -> LazyMainActorService {
		count += 1
		return LazyMainActorService()
	}
}

// MainActor 격리 안에서 override 가능한 lazy Factory를 평가할 graph
@MainActor
@DependencyGraph(overrides: true)
final class LazyOverrideMainActorGraph {
	// 원본 lazy MainActor 결과 생성
	@Provide(.lazy)
	private func makeLazyMainActorService() -> LazyMainActorService {
		LazyMainActorService()
	}
}

// lazy Factory가 source graph의 transient 결과를 최초 접근까지 미루는지 확인
@Test
func lazyProviderDefersSourceGraphAccessUntilFirstAccess() {
	let source = LazySourceGraph()
	let graph = LazySourceFeatureGraph(lazySourceGraph: source)

	#expect(source.count == 0)
	#expect(graph.lazySourceInput.sequence == 1)
	#expect(source.count == 1)
	#expect(graph.lazySourceInput.sequence == 1)
	#expect(source.count == 1)
}

// override source graph도 lazy 원본 Factory에서 최초 접근까지 읽지 않는지 확인
@Test
func lazyOverrideProviderDefersSourceGraphAccessUntilFirstAccess() {
	let source = LazySourceGraph()
	let graph = LazyOverrideSourceFeatureGraph.override().build(lazySourceGraph: source)

	#expect(source.count == 0)
	#expect(graph.lazySourceInput.sequence == 1)
	#expect(source.count == 1)
}

// lazy Factory가 원래 `#function` 문맥과 반환 타입을 보존하는지 확인
@Test
func lazyProviderPreservesFunctionContextAndReturnTypes() throws {
	#expect(LazyFunctionGraph().string == "makeLazyFunctionIdentifier()")

	let graph = LazyReturnTypeGraph()
	let repository = try #require(graph.lazyRepository as? LazyLiveRepository)
	let base = try #require(graph.lazyRepositoryBase as? LazyRepositorySubclass)

	#expect(repository === graph.lazyRepository as? LazyLiveRepository)
	#expect(base === graph.lazyRepositoryBase as? LazyRepositorySubclass)
	#expect(graph.lazyBodylessConfiguration === graph.lazyBodylessConfiguration)
}

// actor graph가 lazy 결과를 actor 격리 안에서 한 번만 만드는지 확인
@Test
func lazyProviderPreservesActorIsolation() async {
	let graph = LazyActorGraph()
	let first = await graph.lazyActorService
	let second = await graph.lazyActorService

	#expect(first === second)
	#expect(first.sequence == 1)
}

// actor override graph가 lazy 교체 Factory를 actor 격리 안에서 한 번만 평가하는지 확인
@Test
func lazyOverrideProviderPreservesActorIsolation() async {
	let graph = LazyOverrideActorGraph.override(
		lazyActorService: .replace {
			LazyActorService(sequence: 9)
		}
	).build()
	let first = await graph.lazyActorService
	let second = await graph.lazyActorService

	#expect(first === second)
	#expect(first.sequence == 9)
}

// MainActor graph가 lazy 결과를 MainActor 안에서 한 번만 만드는지 확인
@Test
@MainActor
func lazyProviderPreservesMainActorIsolation() {
	let graph = LazyMainActorGraph()
	let first = graph.lazyMainActorService
	let second = graph.lazyMainActorService

	#expect(first === second)
}

// MainActor override graph가 lazy 교체 Factory를 한 번만 평가하는지 확인
@Test
@MainActor
func lazyOverrideProviderPreservesMainActorIsolation() {
	let graph = LazyOverrideMainActorGraph.override(
		lazyMainActorService: .replace {
			LazyMainActorService()
		}
	).build()
	let first = graph.lazyMainActorService
	let second = graph.lazyMainActorService

	#expect(first === second)
}
