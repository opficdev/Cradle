//
//  SharedDependencyGraphTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import Cradle
import Foundation
import Testing

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

	@Provide(.shared)
	private func makeSharedLeaf() -> SharedLeaf {
		return SharedLeaf()
	}

	@Provide(.shared)
	private func makeSharedFirstBranch(leaf: SharedLeaf) -> SharedFirstBranch {
		return SharedFirstBranch(leaf: leaf)
	}

	@Provide(.shared)
	private func makeSharedSecondBranch(leaf: SharedLeaf) -> SharedSecondBranch {
		return SharedSecondBranch(leaf: leaf)
	}

	@Provide(.shared)
	private func makeSharedRoot(
		first: SharedFirstBranch,
		second: SharedSecondBranch
	) -> SharedRoot {
		return SharedRoot(first: first, second: second)
	}

	@Provide(.transient)
	private func makeTransientSharedConsumer(root: SharedRoot) -> TransientSharedConsumer {
		transientSequence += 1
		return TransientSharedConsumer(root: root, sequence: transientSequence)
	}
}

// 생성 순서를 안전하게 보관할 probe
final class SharedCreationOrderProbe: @unchecked Sendable {
	static let shared = SharedCreationOrderProbe()

	private let lock = NSLock()
	private var values: [String] = []

	func reset() {
		lock.withLock {
			values = []
		}
	}

	func record(_ value: String) {
		lock.withLock {
			values.append(value)
		}
	}

	func snapshot() -> [String] {
		lock.withLock {
			values
		}
	}
}

// shared 생성 순서만 독립적으로 확인할 graph
@DependencyGraph
final class SharedCreationOrderGraph {
	init() {
		SharedCreationOrderProbe.shared.record("init")
	}

	@Provide(.shared)
	private func makeSharedLeaf() -> SharedLeaf {
		SharedCreationOrderProbe.shared.record("leaf")
		return SharedLeaf()
	}

	@Provide(.shared)
	private func makeSharedFirstBranch(leaf: SharedLeaf) -> SharedFirstBranch {
		SharedCreationOrderProbe.shared.record("first")
		return SharedFirstBranch(leaf: leaf)
	}

	@Provide(.shared)
	private func makeSharedSecondBranch(leaf: SharedLeaf) -> SharedSecondBranch {
		SharedCreationOrderProbe.shared.record("second")
		return SharedSecondBranch(leaf: leaf)
	}

	@Provide(.shared)
	private func makeSharedRoot(
		first: SharedFirstBranch,
		second: SharedSecondBranch
	) -> SharedRoot {
		SharedCreationOrderProbe.shared.record("root")
		return SharedRoot(first: first, second: second)
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

// 독립 #function 문맥 값을 함께 보관할 값
struct FunctionContextValues: Equatable {
	let initializer: String
	let getter: String
	let setter: String
	let subscriptValue: String
	let method: String
}

// shared Factory의 독립 #function 문맥 결과
struct SharedFunctionContext {
	let values: FunctionContextValues
}

// transient Factory의 독립 #function 문맥 결과
struct TransientFunctionContext {
	let values: FunctionContextValues
}

// shared와 transient Factory의 독립 #function 문맥을 비교할 graph
@DependencyGraph
final class NestedFunctionContextGraph {
	@Provide(.shared)
	private func makeSharedFunctionContext() -> SharedFunctionContext {
		struct Context {
			let initializer: String
			var storedSetter = ""

			init() {
				initializer = #function
			}

			var getter: String { #function }

			var setter: String {
				get { storedSetter }
				set {
					_ = newValue
					storedSetter = #function
				}
			}

			subscript(_ index: Int) -> String { #function }

			func method() -> String { #function }
		}

		var context = Context()
		context.setter = "shared"
		return SharedFunctionContext(
			values: FunctionContextValues(
				initializer: context.initializer,
				getter: context.getter,
				setter: context.setter,
				subscriptValue: context[0],
				method: context.method()
			)
		)
	}

	@Provide(.transient)
	private func makeTransientFunctionContext() -> TransientFunctionContext {
		struct Context {
			let initializer: String
			var storedSetter = ""

			init() {
				initializer = #function
			}

			var getter: String { #function }

			var setter: String {
				get { storedSetter }
				set {
					_ = newValue
					storedSetter = #function
				}
			}

			subscript(_ index: Int) -> String { #function }

			func method() -> String { #function }
		}

		var context = Context()
		context.setter = "transient"
		return TransientFunctionContext(
			values: FunctionContextValues(
				initializer: context.initializer,
				getter: context.getter,
				setter: context.setter,
				subscriptValue: context[0],
				method: context.method()
			)
		)
	}
}

// bodyless shared initializer 확장을 확인할 graph
@DependencyGraph
final class BodylessSharedGraph {
	@Provide(.shared)
	private func makeBodylessSharedConfiguration() -> BodylessSharedConfiguration
}

// shared가 사용자 initializer보다 먼저 생성되고 chain·diamond를 한 번만 만드는지 확인
@Test
func sharedDependencyGraphBuildsBeforeInitializerInTopologicalOrder() {
	SharedCreationOrderProbe.shared.reset()
	let graph = SharedCreationOrderGraph()

	#expect(SharedCreationOrderProbe.shared.snapshot() == ["leaf", "first", "second", "root", "init"])
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

// shared와 transient Factory가 독립 #function 문맥을 같게 보존하는지 확인
@Test
func sharedDependencyGraphPreservesNestedFunctionContexts() {
	let graph = NestedFunctionContextGraph()
	let expected = FunctionContextValues(
		initializer: "init()",
		getter: "getter",
		setter: "setter",
		subscriptValue: "subscript(_:)",
		method: "method()"
	)

	#expect(graph.sharedFunctionContext.values == expected)
	#expect(graph.transientFunctionContext.values == expected)
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
