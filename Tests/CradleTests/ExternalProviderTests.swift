//
//  ExternalProviderTests.swift
//  CradleTests
//
//  Created by opfic on 9/4/26.
//

import Cradle
import Testing

// 외부 입력 생성 결과가 보관한 graph 의존성
final class ExternalProviderRepository {}

// 외부 입력과 graph 의존성을 함께 받은 생성 결과
final class ExternalProviderProfile {
	// graph가 생성한 의존성
	let repository: ExternalProviderRepository
	// 호출자가 전달한 식별자
	let id: Int
	// 호출자가 다른 외부 레이블로 전달한 이름
	let name: String

	// 생성 메서드 입력 보관
	init(repository: ExternalProviderRepository, id: Int, name: String) {
		self.repository = repository
		self.id = id
		self.name = name
	}
}

// 원본 Factory 호출 횟수 확인 상태
final class ExternalProviderProbe {
	// 생성 메서드가 실행한 Factory 횟수
	var count = 0
}

// 본문 없는 Factory initializer에 연결할 graph 의존성
struct ExternalProviderBodylessDependency {
	// 생성 결과에서 확인할 값
	let value: Int
}

// 본문 없는 Factory가 initializer로 만들 결과
struct ExternalProviderBodylessResult {
	// graph가 전달한 의존성
	let dependency: ExternalProviderBodylessDependency
	// 호출자가 전달한 외부 입력
	let input: Int
}

// graph 의존성과 외부 입력 생성 검증 graph
@DependencyGraph
final class ExternalProviderGraph {
	// Factory 호출 횟수 기록 상태
	private let probe: ExternalProviderProbe

	// 호출 횟수 기록 상태 주입
	init(probe: ExternalProviderProbe) {
		self.probe = probe
	}

	// 생성 메서드마다 새 graph 의존성 생성
	@Provide(.transient)
	private func makeExternalProviderRepository() -> ExternalProviderRepository {
		ExternalProviderRepository()
	}

	// graph 의존성과 호출자 입력으로 결과 생성
	@Provide(.transient)
	private func makeExternalProviderProfile(
		repository: ExternalProviderRepository,
		@External _ id: Int,
		@External displayName name: String
	) -> ExternalProviderProfile {
		probe.count += 1
		return ExternalProviderProfile(repository: repository, id: id, name: name)
	}
}

// 본문 없는 Factory의 graph 의존성과 외부 입력 전달 확인용 graph
@DependencyGraph
final class ExternalProviderBodylessGraph {
	// 본문 없는 Factory에 전달할 graph 의존성 생성
	@Provide(.transient)
	private func makeExternalProviderBodylessDependency() -> ExternalProviderBodylessDependency {
		ExternalProviderBodylessDependency(value: 29)
	}

	// 반환 타입 initializer를 호출할 외부 입력 Factory
	@Provide(.transient)
	private func makeExternalProviderBodylessResult(
		dependency: ExternalProviderBodylessDependency,
		@External input: Int
	) -> ExternalProviderBodylessResult
}

// 외부 입력만 노출하고 호출마다 원본 Factory를 실행하는지 확인
@Test
func externalProviderMethodCallsFactoryWithExternalValues() {
	let probe = ExternalProviderProbe()
	let graph = ExternalProviderGraph(probe: probe)
	let first = graph.externalProviderProfile(1, displayName: "첫 번째")
	let second = graph.externalProviderProfile(2, displayName: "두 번째")

	#expect(first.id == 1)
	#expect(first.name == "첫 번째")
	#expect(second.id == 2)
	#expect(second.name == "두 번째")
	#expect(first.repository !== second.repository)
	#expect(probe.count == 2)
}

// graph가 생성 메서드 반환값을 보관하지 않는지 확인
@Test
func externalProviderMethodDoesNotRetainResult() {
	let graph = ExternalProviderGraph(probe: ExternalProviderProbe())
	weak var result: ExternalProviderProfile?

	do {
		let profile = graph.externalProviderProfile(1, displayName: "해제")
		result = profile
		#expect(result != nil)
	}

	#expect(result == nil)
}

// 본문 없는 Factory가 실제 생성 메서드에서 initializer를 호출하는지 확인
@Test
func externalProviderBodylessMethodCallsInitializer() {
	let graph = ExternalProviderBodylessGraph()
	let result = graph.externalProviderBodylessResult(input: 1)

	#expect(result.dependency.value == 29)
	#expect(result.input == 1)
}
