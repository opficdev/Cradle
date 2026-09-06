//
//  LazyDependencyGraphTests.swift
//  CradleTests
//
//  Created by opfic on 9/6/26.
//

import Cradle
import Testing

// lazy Factory의 실행 횟수를 기록할 graph별 probe
final class LazyFactoryProbe {
	// 생성한 leaf 수
	var leafCount = 0
	// 생성한 branch 수
	var branchCount = 0
	// 생성한 미사용 값 수
	var unusedCount = 0
}

// graph가 lazy로 보관할 leaf 참조 값
final class LazyLeaf {
	// 생성 순번
	let sequence: Int

	// 생성 순번 보관
	init(sequence: Int) {
		self.sequence = sequence
	}
}

// lazy leaf를 요구하는 lazy branch 값
final class LazyBranch {
	// 주입한 leaf
	let leaf: LazyLeaf

	// leaf 보관
	init(leaf: LazyLeaf) {
		self.leaf = leaf
	}
}

// graph 상태를 lazy Factory가 읽는지 확인할 값
final class LazyStateValue {
	// 최초 접근 시 읽은 상태
	let value: Int

	// 상태 값 보관
	init(value: Int) {
		self.value = value
	}
}

// graph 상태와 등록별 lazy 평가를 확인할 graph
@DependencyGraph
final class LazyDependencyGraph {
	// Factory 실행 횟수 기록
	private let probe: LazyFactoryProbe
	// 최초 접근 전 변경 가능한 graph 상태
	private var state = 0

	// graph 상태와 probe를 주입한 graph 생성
	init(probe: LazyFactoryProbe) {
		self.probe = probe
	}

	// graph 상태 갱신
	func updateState(to value: Int) {
		state = value
	}

	// 최초 접근에 leaf 생성
	@Provide(.lazy)
	private func makeLazyLeaf() -> LazyLeaf {
		probe.leafCount += 1
		return LazyLeaf(sequence: probe.leafCount)
	}

	// lazy leaf를 연결해 최초 접근에 branch 생성
	@Provide(.lazy)
	private func makeLazyBranch(leaf: LazyLeaf) -> LazyBranch {
		probe.branchCount += 1
		return LazyBranch(leaf: leaf)
	}

	// 접근하지 않은 Factory의 지연 생성 확인
	@Provide(.lazy)
	private func makeUnusedLazyValue() -> String {
		probe.unusedCount += 1
		return "unused"
	}

	// Factory 실행 시점의 graph 상태 생성
	@Provide(.lazy)
	private func makeLazyStateValue() -> LazyStateValue {
		LazyStateValue(value: state)
	}
}

// lazy 결과를 교체할 override graph 값
final class LazyOverrideService {
	// 교체 여부 확인 값
	let value: Int

	// 교체 결과 보관
	init(value: Int) {
		self.value = value
	}
}

// lazy 교체 Factory의 지연 실행 확인용 graph
@DependencyGraph(overrides: true)
final class LazyOverrideGraph {
	// 원본 또는 교체 Factory를 lazy로 평가
	@Provide(.lazy)
	private func makeLazyOverrideService() -> LazyOverrideService {
		LazyOverrideService(value: 1)
	}
}

// graph 생성과 미사용 등록이 lazy Factory를 실행하지 않는지 확인
@Test
func lazyDependencyGraphDefersUnusedFactoriesUntilAccess() {
	let probe = LazyFactoryProbe()
	let graph = LazyDependencyGraph(probe: probe)

	#expect(probe.leafCount == 0)
	#expect(probe.branchCount == 0)
	#expect(probe.unusedCount == 0)

	let branch = graph.lazyBranch

	#expect(probe.leafCount == 1)
	#expect(probe.branchCount == 1)
	#expect(probe.unusedCount == 0)
	#expect(branch === graph.lazyBranch)
	#expect(branch.leaf === graph.lazyLeaf)
}

// lazy Factory가 graph 생성 뒤 변경한 상태를 최초 접근에 읽는지 확인
@Test
func lazyDependencyGraphReadsGraphStateAtFirstAccess() {
	let graph = LazyDependencyGraph(probe: LazyFactoryProbe())
	graph.updateState(to: 8)

	#expect(graph.lazyStateValue.value == 8)
}

// graph마다 lazy 결과를 독립적으로 보관하는지 확인
@Test
func lazyDependencyGraphSeparatesGraphInstances() {
	let first = LazyDependencyGraph(probe: LazyFactoryProbe())
	let second = LazyDependencyGraph(probe: LazyFactoryProbe())

	#expect(first.lazyLeaf !== second.lazyLeaf)
	#expect(first.lazyLeaf.sequence == 1)
	#expect(second.lazyLeaf.sequence == 1)
}

// override builder와 build가 lazy 교체 Factory를 실행하지 않는지 확인
@Test
func lazyOverrideGraphDefersReplacementUntilAccess() {
	var count = 0
	let builder = LazyOverrideGraph.override(
		lazyOverrideService: .replace {
			count += 1
			return LazyOverrideService(value: 9)
		}
	)

	#expect(count == 0)
	let graph = builder.build()
	#expect(count == 0)

	#expect(graph.lazyOverrideService.value == 9)
	#expect(count == 1)
	#expect(graph.lazyOverrideService.value == 9)
	#expect(count == 1)
}
