//
//  SharedDependencyGraphTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import Cradle
import Testing

// shared 생성 순서와 호출 횟수를 기록할 probe
enum SharedDependencyGraphProbe {
	// 테스트가 순차 실행할 기록
	nonisolated(unsafe) static var events: [String] = []
}

// graph가 소유할 shared 참조 값
final class SharedLeaf {}

// shared leaf를 요구하는 첫 번째 분기
final class SharedFirstBranch {
	let leaf: SharedLeaf

	init(leaf: SharedLeaf) {
		self.leaf = leaf
	}
}

// shared leaf를 요구하는 두 번째 분기
final class SharedSecondBranch {
	let leaf: SharedLeaf

	init(leaf: SharedLeaf) {
		self.leaf = leaf
	}
}

// 두 shared 분기를 요구하는 diamond 정점
final class SharedRoot {
	let first: SharedFirstBranch
	let second: SharedSecondBranch

	init(first: SharedFirstBranch, second: SharedSecondBranch) {
		self.first = first
		self.second = second
	}
}

// shared 값을 매번 새로 받을 transient 결과
struct TransientSharedConsumer {
	let root: SharedRoot
	let sequence: Int
}

// shared chain·diamond와 transient consumer를 함께 확인할 graph
@DependencyGraph
final class SharedDependencyGraph {
	private var transientSequence = 0

	init() {
		SharedDependencyGraphProbe.events.append("init")
	}

	@Provide(.shared)
	private func makeSharedLeaf() -> SharedLeaf {
		SharedDependencyGraphProbe.events.append("leaf")
		return SharedLeaf()
	}

	@Provide(.shared)
	private func makeSharedFirstBranch(leaf: SharedLeaf) -> SharedFirstBranch {
		SharedDependencyGraphProbe.events.append("first")
		return SharedFirstBranch(leaf: leaf)
	}

	@Provide(.shared)
	private func makeSharedSecondBranch(leaf: SharedLeaf) -> SharedSecondBranch {
		SharedDependencyGraphProbe.events.append("second")
		return SharedSecondBranch(leaf: leaf)
	}

	@Provide(.shared)
	private func makeSharedRoot(
		first: SharedFirstBranch,
		second: SharedSecondBranch
	) -> SharedRoot {
		SharedDependencyGraphProbe.events.append("root")
		return SharedRoot(first: first, second: second)
	}

	@Provide
	private func makeTransientSharedConsumer(root: SharedRoot) -> TransientSharedConsumer {
		transientSequence += 1
		return TransientSharedConsumer(root: root, sequence: transientSequence)
	}
}

// shared Factory의 #function 보존을 확인할 graph
@DependencyGraph
final class SharedFunctionGraph {
	@Provide(.shared)
	private func makeFunctionIdentifier() -> String {
		#function
	}
}

// shared 반환 타입으로 노출할 프로토콜 계약
protocol SharedRepository {
	var token: Int { get }
}

// 프로토콜 뒤에 숨길 shared 구현
final class LiveSharedRepository: SharedRepository {
	let token = 21
}

// shared 반환 타입으로 노출할 상위 클래스
class SharedRepositoryBase {}

// 상위 클래스 뒤에 숨길 shared 하위 구현
final class LiveSharedRepositorySubclass: SharedRepositoryBase {}

// protocol과 superclass 반환 타입을 shared로 보관할 graph
@DependencyGraph
final class SharedReturnTypeGraph {
	@Provide(.shared)
	private func makeSharedRepository() -> any SharedRepository {
		LiveSharedRepository()
	}

	@Provide(.shared)
	private func makeSharedRepositoryBase() -> SharedRepositoryBase {
		LiveSharedRepositorySubclass()
	}
}

// bodyless concrete Factory를 shared로 보관할 참조 값
final class BodylessSharedConfiguration {}

// bodyless shared initializer 확장을 확인할 graph
@DependencyGraph
final class BodylessSharedGraph {
	@Provide(.shared)
	private func makeBodylessSharedConfiguration() -> BodylessSharedConfiguration
}

// shared가 사용자 initializer보다 먼저 생성되고 chain·diamond를 한 번만 만드는지 확인
@Test
func sharedDependencyGraphBuildsBeforeInitializerInTopologicalOrder() {
	SharedDependencyGraphProbe.events = []
	let graph = SharedDependencyGraph()

	#expect(SharedDependencyGraphProbe.events == ["leaf", "first", "second", "root", "init"])
	#expect(graph.sharedFirstBranch.leaf === graph.sharedSecondBranch.leaf)
	#expect(graph.sharedRoot.first === graph.sharedFirstBranch)
	#expect(graph.sharedRoot.second === graph.sharedSecondBranch)
}

// transient consumer는 매번 새로 만들고 같은 shared root를 전달받는지 확인
@Test
func sharedDependencyGraphReusesSharedValuesAndRecreatesTransientConsumers() {
	let graph = SharedDependencyGraph()
	let first = graph.transientSharedConsumer
	let second = graph.transientSharedConsumer

	#expect(first.sequence == 1)
	#expect(second.sequence == 2)
	#expect(first.root === second.root)
	#expect(first.root === graph.sharedRoot)
}

// graph마다 독립 shared 저장소를 소유하는지 확인
@Test
func sharedDependencyGraphSeparatesGraphInstances() {
	let first = SharedDependencyGraph()
	let second = SharedDependencyGraph()

	#expect(first.sharedLeaf !== second.sharedLeaf)
	#expect(first.sharedRoot !== second.sharedRoot)
}

// static helper로 옮긴 shared 본문이 원래 Factory의 #function 값을 보존하는지 확인
@Test
func sharedDependencyGraphPreservesOriginalFunctionIdentifier() {
	#expect(SharedFunctionGraph().string == "makeFunctionIdentifier()")
}

// shared 저장소가 protocol·superclass 반환 타입을 보존하는지 확인
@Test
func sharedDependencyGraphPreservesAbstractReturnTypes() throws {
	let graph = SharedReturnTypeGraph()
	let repository = try #require(graph.sharedRepository as? LiveSharedRepository)
	let base = try #require(graph.sharedRepositoryBase as? LiveSharedRepositorySubclass)

	#expect(repository.token == 21)
	#expect(repository === graph.sharedRepository as? LiveSharedRepository)
	#expect(base === graph.sharedRepositoryBase as? LiveSharedRepositorySubclass)
}

// bodyless concrete Factory가 shared 저장소에서 같은 참조를 반환하는지 확인
@Test
func sharedDependencyGraphBuildsBodylessConcreteValue() {
	let graph = BodylessSharedGraph()
	#expect(graph.bodylessSharedConfiguration === graph.bodylessSharedConfiguration)
}

// graph가 해제되면 외부 참조가 없는 shared 값도 해제할 수 있는지 확인
@Test
func sharedDependencyGraphReleasesOwnedValues() {
	weak var observed: SharedLeaf?
	do {
		let graph = SharedDependencyGraph()
		observed = graph.sharedLeaf
		withExtendedLifetime(graph) {
			#expect(observed != nil)
		}
	}
	#expect(observed == nil)
}
