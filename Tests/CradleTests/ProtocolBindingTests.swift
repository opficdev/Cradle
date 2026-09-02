//
//  ProtocolBindingTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Cradle
import Testing

// 구현 종류와 관계없이 전달할 계약
protocol BindingService {
	// 전달된 구현의 검증값
	var token: Int { get }
}

// 값 타입 구현
struct BindingValue: BindingService {
	// 값 타입 전달 검증값
	let token = 11
}

// 참조 타입 구현
final class BindingReference: BindingService {
	// 참조 타입 전달 검증값
	let token = 22
}

// 그래프가 아닌 의존성 값으로 전달할 actor 구현
actor BindingActor: BindingService {
	// actor 격리 밖에서 읽을 수 있는 불변 검증값
	nonisolated let token = 33
}

// 프로토콜만 아는 소비자
struct BindingConsumer {
	// Factory에서 전달한 의존성
	let bindingService: any BindingService
}

// 다단계 연결의 끝에서 읽을 소비자
struct BindingRoot {
	// 프로토콜을 전달받은 중간 소비자
	let bindingConsumer: BindingConsumer
}

// 사용자 Factory 호출과 프로토콜 연결을 확인할 그래프
@DependencyGraph
final class ProtocolBindingGraph {
	// 테스트에서 선택한 구현 생성 함수
	private let create: () -> any BindingService
	// 실제 의존성 Factory 호출 횟수
	private(set) var calls = 0
	// 다단계 Factory 호출 순서
	private(set) var invocations = [String]()

	// 사용자 Factory 보관
	init(create: @escaping () -> any BindingService) {
		self.create = create
	}

	// 캐시 없이 사용자 Factory 결과 반환
	@Provide
	private func makeBindingService() -> any BindingService {
		calls += 1
		invocations.append("service")
		return create()
	}

	// 생성 접근자를 경유해 프로토콜 소비자 생성
	@Provide
	private func makeBindingConsumer(bindingService: any BindingService) -> BindingConsumer {
		invocations.append("consumer")
		return BindingConsumer(bindingService: bindingService)
	}

	// 중간 소비자의 생성 접근자로 다단계 연결
	@Provide
	private func makeBindingRoot(bindingConsumer: BindingConsumer) -> BindingRoot {
		invocations.append("root")
		return BindingRoot(bindingConsumer: bindingConsumer)
	}

}

// 선언 순서를 뒤집은 동일한 프로토콜 연결 그래프
@DependencyGraph
final class ReversedProtocolBindingGraph {
	// 역순 선언에서도 비교할 Factory 호출 순서
	private(set) var invocations = [String]()

	// 의존 Factory보다 앞에 선언한 최종 소비자
	@Provide
	private func makeBindingRoot(bindingConsumer: BindingConsumer) -> BindingRoot {
		invocations.append("root")
		return BindingRoot(bindingConsumer: bindingConsumer)
	}

	// 의존 Factory보다 앞에 선언한 중간 소비자
	@Provide
	private func makeBindingConsumer(bindingService: any BindingService) -> BindingConsumer {
		invocations.append("consumer")
		return BindingConsumer(bindingService: bindingService)
	}

	// 마지막에 선언해도 먼저 호출할 의존성 Factory
	@Provide
	private func makeBindingService() -> any BindingService {
		invocations.append("service")
		return BindingValue()
	}
}

// 상위 클래스 타입으로 등록할 구현
class RepositorySuperclass {}

// 상위 클래스에 연결할 하위 구현
final class LiveRepositorySubclass: RepositorySuperclass {}

// 상위 클래스 타입만 아는 소비자
struct SuperclassBindingConsumer {
	// Factory에서 전달한 상위 클래스 타입 의존성
	let repository: RepositorySuperclass
}

// 상위 클래스 반환 타입의 연결을 확인할 graph
@DependencyGraph
final class SuperclassBindingGraph {
	// 하위 구현을 상위 클래스 등록 타입으로 노출하는 Factory
	@Provide
	private func makeRepositorySuperclass() -> RepositorySuperclass {
		LiveRepositorySubclass()
	}

	// 상위 클래스 타입을 요구하는 소비자 Factory
	@Provide
	private func makeSuperclassBindingConsumer(
		repository: RepositorySuperclass
	) -> SuperclassBindingConsumer {
		SuperclassBindingConsumer(repository: repository)
	}
}

// class·struct·actor를 같은 프로토콜로 전달하고 반복 호출 확인
@Test
func protocolBindingDeliversImplementationsWithoutCaching() {
	// 서로 다른 구현의 생성 함수를 같은 반환 계약으로 묶은 목록
	let factories: [() -> any BindingService] = [
		{ BindingValue() }, { BindingReference() }, { BindingActor() }
	]

	for (create, token) in zip(factories, [11, 22, 33]) {
		// 구현별 독립 그래프
		let graph = ProtocolBindingGraph(create: create)
		#expect(graph.bindingConsumer.bindingService.token == token)
		#expect(graph.bindingConsumer.bindingService.token == token)
		#expect(graph.calls == 2)
	}
}

// 매 호출의 생성 정책이 사용자 Factory에 있음을 확인
@Test
func protocolBindingPreservesFactoryIdentityPolicy() throws {
	// 매번 새 값을 반환할 그래프
	let graph = ProtocolBindingGraph(create: { BindingReference() })
	// 첫 번째 결과
	let first = try #require(graph.bindingService as? BindingReference)
	// 두 번째 결과
	let second = try #require(graph.bindingService as? BindingReference)
	#expect(first !== second)
	#expect(graph.calls == 2)

	// 사용자 Factory가 재사용할 값
	let shared = BindingReference()
	// 저장된 값을 반환할 그래프
	let sharedGraph = ProtocolBindingGraph(create: { shared })
	#expect(try #require(sharedGraph.bindingService as? BindingReference) === shared)
	#expect(try #require(sharedGraph.bindingService as? BindingReference) === shared)
	#expect(sharedGraph.calls == 2)
}

// 프로토콜 의존성에서 최종 소비자까지 다단계 전달 확인
@Test
func protocolBindingBuildsMultipleSteps() {
	// 다단계 연결을 확인할 그래프
	let graph = ProtocolBindingGraph(create: { BindingValue() })
	#expect(graph.bindingRoot.bindingConsumer.bindingService.token == 11)
	#expect(graph.calls == 1)
	#expect(graph.invocations == ["service", "consumer", "root"])
}

// Factory 선언 순서를 바꿔도 전달 결과와 호출 순서가 같은지 확인
@Test
func protocolBindingIgnoresDeclarationOrder() {
	// 의존 순서대로 선언한 그래프
	let graph = ProtocolBindingGraph(create: { BindingValue() })
	// 의존 순서를 뒤집은 그래프
	let reversed = ReversedProtocolBindingGraph()
	// 의존 순서대로 생성한 결과
	let root = graph.bindingRoot
	// 역순 선언에서 생성한 결과
	let reversedRoot = reversed.bindingRoot
	#expect(root.bindingConsumer.bindingService.token == reversedRoot.bindingConsumer.bindingService.token)
	#expect(graph.invocations == ["service", "consumer", "root"])
	#expect(reversed.invocations == graph.invocations)
}

// 상위 클래스 반환 타입이 생성 프로퍼티와 소비자에 유지되는지 확인
@Test
func superclassBindingDeliversSubclassImplementation() {
	let graph = SuperclassBindingGraph()
	#expect(graph.repositorySuperclass is LiveRepositorySubclass)
	#expect(graph.superclassBindingConsumer.repository is LiveRepositorySubclass)
}
