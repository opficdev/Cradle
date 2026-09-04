//
//  ExternalProviderOverrideTests.swift
//  CradleTests
//
//  Created by opfic on 9/4/26.
//

import Cradle
import Testing

// 외부 입력 override Factory에 graph가 전달할 shared 의존성
final class ExternalProviderOverrideRepository {
	// 원본과 교체 결과에 포함할 값
	let value = 29
}

// 원본과 교체 Factory 결과
struct ExternalProviderOverrideResult {
	// 실행한 Factory와 입력 확인 값
	let value: String
}

// 외부 입력 원본·교체 Factory 검증 graph
@DependencyGraph(overrides: true)
final class ExternalProviderOverrideGraph {
	// graph가 한 번 보관할 의존성 생성
	@Provide
	private func makeExternalProviderOverrideRepository() -> ExternalProviderOverrideRepository {
		ExternalProviderOverrideRepository()
	}

	// graph 의존성과 호출자 입력으로 원본 결과 생성
	@Provide(.transient)
	private func makeExternalProviderOverrideResult(
		repository: ExternalProviderOverrideRepository,
		@External id: Int
	) -> ExternalProviderOverrideResult {
		ExternalProviderOverrideResult(value: "original-\(repository.value)-\(id)")
	}
}

// `.original`이 생성 메서드 호출 시 외부 입력을 받는지 확인
@Test
func externalProviderOverrideUsesOriginalFactory() {
	let graph = ExternalProviderOverrideGraph.override().build()
	let result = graph.externalProviderOverrideResult(id: 1)

	#expect(result.value == "original-29-1")
}

// `.replace`가 graph 의존성과 외부 입력을 전체 Factory 순서로 받는지 확인
@Test
func externalProviderOverrideUsesReplacementFactory() {
	let builder = ExternalProviderOverrideGraph.override(
		externalProviderOverrideResult: .replace { repository, id in
			ExternalProviderOverrideResult(value: "replacement-\(repository.value)-\(id)")
		}
	)
	let graph = builder.build()
	let result = graph.externalProviderOverrideResult(id: 2)

	#expect(result.value == "replacement-29-2")
}
