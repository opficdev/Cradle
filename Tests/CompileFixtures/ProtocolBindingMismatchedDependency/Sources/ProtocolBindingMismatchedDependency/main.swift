//
//  main.swift
//  ProtocolBindingMismatchedDependency
//
//  Created by opfic on 8/30/26.
//

import Cradle

// 등록된 Factory가 제공하는 계약
protocol ProvidedRepository {}

// 소비자 Factory가 요구하는 다른 계약
protocol ExpectedRepository {}

// 제공하는 계약만 준수하는 구현
struct LiveRepository: ProvidedRepository {}

// 타입이 일치하지 않는 의존성을 요구할 소비자
struct MismatchedConsumer {}

// 이름 연결과 타입 검사의 책임 분리 확인용 그래프
@DependencyGraph
final class MismatchedGraph {
	// 접근자 이름을 제공할 프로토콜 반환 Factory
	@Provide
	private func makeProvidedRepository() -> any ProvidedRepository {
		LiveRepository()
	}

	// 이름은 일치하지만 다른 프로토콜을 요구하는 Factory
	@Provide
	private func makeMismatchedConsumer(providedRepository: any ExpectedRepository) -> MismatchedConsumer {
		MismatchedConsumer()
	}
}
