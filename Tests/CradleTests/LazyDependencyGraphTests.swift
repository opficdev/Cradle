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

// lazy diamond의 공용 leaf를 요구하는 첫 번째 분기
final class LazyFirstDiamondBranch {
	// 공용 leaf 보관
	let leaf: LazyLeaf

	// leaf 보관
	init(leaf: LazyLeaf) {
		self.leaf = leaf
	}
}

// lazy diamond의 공용 leaf를 요구하는 두 번째 분기
final class LazySecondDiamondBranch {
	// 공용 leaf 보관
	let leaf: LazyLeaf

	// leaf 보관
	init(leaf: LazyLeaf) {
		self.leaf = leaf
	}
}

// 두 lazy 분기를 요구하는 diamond 결과
final class LazyDiamondRoot {
	// 첫 번째 분기 보관
	let first: LazyFirstDiamondBranch
	// 두 번째 분기 보관
	let second: LazySecondDiamondBranch

	// 두 분기 보관
	init(first: LazyFirstDiamondBranch, second: LazySecondDiamondBranch) {
		self.first = first
		self.second = second
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

// 원본 lazy override Factory 호출 횟수를 확인할 결과
final class LazyOverrideOriginalService {
	// 원본 Factory의 생성 순번
	let count: Int

	// 생성 순번 보관
	init(count: Int) {
		self.count = count
	}
}

// 원본 lazy override Factory가 `selection` 이름을 써도 되는지 확인할 graph
@DependencyGraph(overrides: true)
final class LazyOverrideOriginalGraph {
	// 원본 Factory 실행 횟수
	private var count = 0

	// generated helper의 지역 이름과 같은 원본 Factory
	@Provide(.lazy)
	private func selection() -> LazyOverrideOriginalService {
		count += 1
		return LazyOverrideOriginalService(count: count)
	}

	// 원본 Factory 실행 횟수 반환
	func factoryCount() -> Int {
		count
	}
}

// `preconditionFailure` 이름 충돌을 확인할 lazy override 결과
final class LazyOverridePreconditionFailureService {}

// 표준 함수 이름과 같은 원본 Factory를 포함한 lazy override graph
@DependencyGraph(overrides: true)
final class LazyOverridePreconditionFailureGraph {
	// generated helper의 실패 경로와 같은 이름의 원본 Factory
	@Provide(.lazy)
	private func preconditionFailure() -> LazyOverridePreconditionFailureService {
		LazyOverridePreconditionFailureService()
	}
}

// lazy diamond의 동일 leaf를 graph별로 보관할 graph
@DependencyGraph
final class LazyDiamondGraph {
	// 공용 leaf 생성
	@Provide(.lazy)
	private func makeLazyLeaf() -> LazyLeaf {
		LazyLeaf(sequence: 1)
	}

	// 첫 번째 diamond 분기 생성
	@Provide(.lazy)
	private func makeLazyFirstDiamondBranch(leaf: LazyLeaf) -> LazyFirstDiamondBranch {
		LazyFirstDiamondBranch(leaf: leaf)
	}

	// 두 번째 diamond 분기 생성
	@Provide(.lazy)
	private func makeLazySecondDiamondBranch(leaf: LazyLeaf) -> LazySecondDiamondBranch {
		LazySecondDiamondBranch(leaf: leaf)
	}

	// 두 분기를 연결한 diamond 결과 생성
	@Provide(.lazy)
	private func makeLazyDiamondRoot(
		first: LazyFirstDiamondBranch,
		second: LazySecondDiamondBranch
	) -> LazyDiamondRoot {
		LazyDiamondRoot(first: first, second: second)
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

// lazy diamond이 공용 의존성을 graph 안에서 한 번만 연결하는지 확인
@Test
func lazyDependencyGraphReusesDiamondLeaf() {
	let graph = LazyDiamondGraph()
	let root = graph.lazyDiamondRoot

	#expect(root.first.leaf === root.second.leaf)
	#expect(root.first.leaf === graph.lazyLeaf)
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

// 원본 lazy override Factory가 build 뒤 첫 접근에서 한 번만 실행되는지 확인
@Test
func lazyOverrideGraphDefersOriginalFactoryUntilAccess() {
	let graph = LazyOverrideOriginalGraph.override().build()

	#expect(graph.factoryCount() == 0)
	#expect(graph.lazyOverrideOriginalService.count == 1)
	#expect(graph.factoryCount() == 1)
	#expect(graph.lazyOverrideOriginalService.count == 1)
	#expect(graph.factoryCount() == 1)
}

// 표준 함수 이름과 같은 lazy Factory도 original 경로에서 호출하는지 확인
@Test
func lazyOverrideGraphSupportsPreconditionFailureFactoryName() {
	let graph = LazyOverridePreconditionFailureGraph.override().build()

	#expect(
		graph.lazyOverridePreconditionFailureService
			=== graph.lazyOverridePreconditionFailureService
	)
}

// lazy 교체 closure의 해제 시점을 확인할 참조 값
private final class LazyOverrideCapture {}

// 최초 평가 뒤 graph가 lazy 교체 closure를 보관하지 않는지 확인
@Test
func lazyOverrideGraphReleasesReplacementAfterFirstAccess() {
	weak var observed: LazyOverrideCapture?
	let graph: LazyOverrideGraph

	do {
		let capture = LazyOverrideCapture()
		observed = capture
		graph = LazyOverrideGraph.override(
			lazyOverrideService: .replace {
				withExtendedLifetime(capture) {
					LazyOverrideService(value: 10)
				}
			}
		).build()
	}

	#expect(observed != nil)
	#expect(graph.lazyOverrideService.value == 10)
	#expect(observed == nil)
}

// graph 해제 뒤 lazy 저장소가 보관한 결과도 함께 해제하는지 확인
@Test
func lazyDependencyGraphReleasesStoredResult() {
	weak var observed: LazyLeaf?

	do {
		let graph = LazyDependencyGraph(probe: LazyFactoryProbe())
		observed = graph.lazyLeaf

		withExtendedLifetime(graph) {
			#expect(observed != nil)
		}
	}

	#expect(observed == nil)
}
