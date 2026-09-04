//
//  ExternalProviderConcurrencyTests.swift
//  CradleTests
//
//  Created by opfic on 9/4/26.
//

import Cradle
import Testing

// actor graph가 외부 입력 결과에 연결할 값
struct ExternalProviderActorRepository: Sendable {
	// 생성 결과 계산에 사용할 값
	let value = 29
}

// actor 경계를 통과할 외부 입력 생성 결과
struct ExternalProviderActorResult: Sendable {
	// 원본과 교체 Factory의 검증값
	let value: Int
}

// 외부 입력 생성 메서드의 actor 격리와 override 전달 확인용 graph
@DependencyGraph(overrides: true)
actor ExternalProviderActorGraph {
	// graph가 한 번 보관할 의존성 생성
	@Provide
	private func makeExternalProviderActorRepository() -> ExternalProviderActorRepository {
		ExternalProviderActorRepository()
	}

	// actor 격리 상태에서 호출자 입력으로 결과 생성
	@Provide(.transient)
	private func makeExternalProviderActorResult(
		repository: ExternalProviderActorRepository,
		@External input: Int
	) -> ExternalProviderActorResult {
		ExternalProviderActorResult(value: repository.value + input)
	}
}

// MainActor 안에서 사용할 호출자 입력
final class ExternalProviderMainActorInput {
	// 생성 결과 계산에 사용할 값
	let value: Int

	// 호출자 입력 생성
	init(value: Int) {
		self.value = value
	}
}

// MainActor 안에서 반환할 외부 입력 생성 결과
final class ExternalProviderMainActorResult {
	// 생성 메서드 검증값
	let value: Int

	// 외부 입력 생성 결과 초기화
	init(value: Int) {
		self.value = value
	}
}

// 외부 입력 생성 메서드의 MainActor 격리 확인용 graph
@MainActor
@DependencyGraph
final class ExternalProviderMainActorGraph {
	// MainActor 안에서 호출자 입력으로 결과 생성
	@Provide(.transient)
	private func makeExternalProviderMainActorResult(
		@External input: ExternalProviderMainActorInput
	) -> ExternalProviderMainActorResult {
		ExternalProviderMainActorResult(value: input.value)
	}
}

// actor 생성 메서드가 호출 시점 입력을 격리된 Factory로 전달하는지 확인
@Test
private func externalProviderActorMethodAcceptsSendableInput() async {
	let graph = ExternalProviderActorGraph()
	let result = await graph.externalProviderActorResult(input: 1)

	#expect(result.value == 30)
}

// actor override의 Sendable Factory가 graph 의존성과 외부 입력을 받는지 확인
@Test
private func externalProviderActorOverrideAcceptsSendableFactory() async {
	let graph = ExternalProviderActorGraph.override(
		externalProviderActorResult: .replace { repository, input in
			ExternalProviderActorResult(value: repository.value * input)
		}
	).build()
	let result = await graph.externalProviderActorResult(input: 2)

	#expect(result.value == 58)
}

// MainActor 생성 메서드가 같은 격리 안의 참조 입력과 결과를 허용하는지 확인
@Test
@MainActor
private func externalProviderMainActorMethodPreservesIsolation() {
	let graph = ExternalProviderMainActorGraph()
	let input = ExternalProviderMainActorInput(value: 3)
	let result = graph.externalProviderMainActorResult(input: input)

	#expect(result.value == 3)
}
