//
//  DependencyGraphRuntimeTests.swift
//  CradleTests
//
//  Created by opfic on 8/29/26.
//

import Cradle
import Foundation
import Testing

// class 반환값 identity 확인용 probe
final class ReferenceProbe {}

// struct 반환값 transient 생성 확인용 probe
struct ValueProbe: Equatable {
	// 각 생성값 구분용 식별자
	let token = UUID()
}

// actor 반환값 identity 확인용 probe
actor ActorProbe {}

// graph 사용자 stored property 전달값 보관
struct ConfigurationValue {
	// graph initializer 수신값 보관
	let token: UUID
}

// 기본 shared Factory의 생성 횟수 기록
final class DefaultSharedCreationProbe: @unchecked Sendable {
	// 모든 기본 shared Factory의 생성 횟수 기록소
	static let shared = DefaultSharedCreationProbe()
	// 생성 횟수 보호용 lock
	private let lock = NSLock()
	// graph 생성 횟수와 비교할 Factory 호출 횟수
	private var value = 0

	// 테스트 시작 전 Factory 호출 횟수 초기화
	func reset() {
		lock.withLock {
			value = 0
		}
	}

	// 기본 shared Factory 호출 횟수 증가
	func record() {
		lock.withLock {
			value += 1
		}
	}

	// 동기화된 Factory 호출 횟수 반환
	func count() -> Int {
		lock.withLock {
			value
		}
	}
}

// 기본 shared 수명 확인용 참조 값
final class DefaultSharedValue {}

// 기본 shared 해제 확인용 참조 값
final class DefaultSharedReleasedValue {}

// graph initializer가 보관할 repository 입력
final class GraphInputRepository {}

// graph initializer가 받은 repository 입력 묶음
struct GraphInput {
	// UseCase 생성에 전달할 repository
	let repository: GraphInputRepository
	// provider 생성 횟수 기록
	let probe: GraphInputCreationProbe
}

// input provider 생성 시점을 기록할 probe
final class GraphInputCreationProbe {
	// shared Factory 실행 횟수
	var sharedCount = 0
	// lazy Factory 실행 횟수
	var lazyCount = 0
}

// input을 읽어 만든 shared 결과
final class GraphInputUseCase {
	// 생성에 사용한 repository
	let repository: GraphInputRepository

	// repository 연결 생성
	init(repository: GraphInputRepository) {
		self.repository = repository
	}
}

// input을 최초 접근에서 읽을 lazy 결과
final class GraphInputLazyValue {
	// 생성에 사용한 repository
	let repository: GraphInputRepository

	// repository 연결 생성
	init(repository: GraphInputRepository) {
		self.repository = repository
	}
}

// initializer input과 provider 수명을 함께 검증할 graph
@DependencyGraph(input: GraphInput.self)
final class GraphInputDependencyGraph {
	// graph 생성 중 input repository로 만들 shared UseCase
	@Provide
	private func makeGraphInputUseCase() -> GraphInputUseCase {
		input.probe.sharedCount += 1
		return GraphInputUseCase(repository: input.repository)
	}

	// 최초 접근에서 input repository로 만들 lazy 값
	@Provide(.lazy)
	private func makeGraphInputLazyValue() -> GraphInputLazyValue {
		input.probe.lazyCount += 1
		return GraphInputLazyValue(repository: input.repository)
	}
}

// 인자 생략 Factory의 graph별 shared 수명 검증용 graph
@DependencyGraph
final class DefaultSharedGraph {
	// graph 생성 중 한 번 만들 기본 shared 값
	@Provide
	private func makeDefaultSharedValue() -> DefaultSharedValue {
		DefaultSharedCreationProbe.shared.record()
		return DefaultSharedValue()
	}
}

// 기본 shared 값의 ARC 해제 검증용 graph
@DependencyGraph
final class DefaultSharedReleaseGraph {
	// graph가 단독 소유할 기본 shared 값
	@Provide
	private func makeDefaultSharedReleasedValue() -> DefaultSharedReleasedValue {
		DefaultSharedReleasedValue()
	}
}

// G1 transient 생성 경로 동작 검증용 graph
@DependencyGraph
final class RuntimeGraph {
	// 사용자 initializer 보관값
	private let token: UUID
	// class factory 호출 횟수 검증용 보관값
	private(set) var invocationCount = 0

	// graph 필요 사용자 값 저장
	init(token: UUID) {
		self.token = token
	}

	// 매 접근별 새 class probe 생성
	@Provide(.transient)
	private func makeReferenceProbe() -> ReferenceProbe {
		invocationCount += 1
		return ReferenceProbe()
	}

	// 매 접근별 새 struct probe 생성
	@Provide(.transient)
	private func makeValueProbe() -> ValueProbe {
		ValueProbe()
	}

	// 매 접근별 새 actor probe 생성
	@Provide(.transient)
	private func makeActorProbe() -> ActorProbe {
		ActorProbe()
	}

	// 사용자 initializer 값을 담은 configuration 생성
	@Provide(.transient)
	private func buildConfigurationValue() -> ConfigurationValue {
		ConfigurationValue(token: token)
	}
}

// class factory의 접근 횟수별 새 instance 생성 확인
@Test
func providerCreatesANewClassInstanceForEachAccess() {
	let graph = RuntimeGraph(token: UUID())
	let first = graph.referenceProbe
	let second = graph.referenceProbe

	#expect(first !== second)
	#expect(graph.invocationCount == 2)
}

// struct와 actor factory별 새 값 생성 확인
@Test
func providerCreatesNewStructAndActorValuesForEachAccess() {
	let graph = RuntimeGraph(token: UUID())

	#expect(graph.valueProbe != graph.valueProbe)
	#expect(graph.actorProbe !== graph.actorProbe)
}

// Macro의 사용자 initializer·stored property 미변경 확인
@Test
func graphKeepsUserInitializerAndStoredProperty() {
	let token = UUID()

	#expect(RuntimeGraph(token: token).configurationValue.token == token)
}

// 기본 Factory가 graph 생성 중 한 번 만들고 graph별로 재사용하는지 확인
@Test
func defaultProviderBuildsAndReusesSharedValue() {
	DefaultSharedCreationProbe.shared.reset()
	let firstGraph = DefaultSharedGraph()

	#expect(DefaultSharedCreationProbe.shared.count() == 1)
	let first = firstGraph.defaultSharedValue
	let repeated = firstGraph.defaultSharedValue
	#expect(first === repeated)
	#expect(DefaultSharedCreationProbe.shared.count() == 1)

	let secondGraph = DefaultSharedGraph()
	let second = secondGraph.defaultSharedValue
	#expect(second !== first)
	#expect(DefaultSharedCreationProbe.shared.count() == 2)
}

// graph가 해제되면 기본 shared 값도 해제할 수 있는지 확인
@Test
func defaultProviderReleasesOwnedSharedValue() {
	weak var observed: DefaultSharedReleasedValue?
	do {
		let graph = DefaultSharedReleaseGraph()
		observed = graph.defaultSharedReleasedValue

		withExtendedLifetime(graph) {
			#expect(observed != nil)
		}
	}
	#expect(observed == nil)
}

// 기본 shared provider가 initializer input 대입 뒤 생성되는지 확인
@Test
func defaultProviderReadsInitializerInputDuringGraphCreation() {
	let repository = GraphInputRepository()
	let probe = GraphInputCreationProbe()
	let graph = GraphInputDependencyGraph(input: GraphInput(repository: repository, probe: probe))

	#expect(probe.sharedCount == 1)
	#expect(probe.lazyCount == 0)
	#expect(graph.graphInputUseCase.repository === repository)
	#expect(graph.graphInputUseCase === graph.graphInputUseCase)
}

// lazy provider가 initializer input을 최초 접근까지 읽지 않는지 확인
@Test
func lazyProviderReadsInitializerInputAtFirstAccess() {
	let repository = GraphInputRepository()
	let probe = GraphInputCreationProbe()
	let graph = GraphInputDependencyGraph(input: GraphInput(repository: repository, probe: probe))

	#expect(probe.lazyCount == 0)
	#expect(graph.graphInputLazyValue.repository === repository)
	#expect(probe.lazyCount == 1)
	#expect(graph.graphInputLazyValue === graph.graphInputLazyValue)
	#expect(probe.lazyCount == 1)
}

// shared helper가 Factory 지역 이름보다 graph input을 우선하는지 확인
@Test
func defaultProviderPreservesInputReferenceWhenFactoryDeclaresSameHelperName() {
	let repository = GraphInputRepository()
	let probe = GraphInputCreationProbe()
	let graph = GraphInputShadowingDependencyGraph(
		input: GraphInput(repository: repository, probe: probe)
	)

	#expect(graph.graphInputUseCase.repository === repository)
}

// helper 매개변수와 같은 이름을 가진 지역 선언 회귀 검증용 graph
@DependencyGraph(input: GraphInput.self)
final class GraphInputShadowingDependencyGraph {
	// graph input을 읽는 shared UseCase 생성
	@Provide
	private func makeGraphInputUseCase() -> GraphInputUseCase {
		let graphInput = GraphInput(repository: GraphInputRepository(), probe: input.probe)
		_ = graphInput
		return GraphInputUseCase(repository: input.repository)
	}
}
