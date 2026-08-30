//
//  main.swift
//  ProtocolBindingNonconformingImplementation
//
//  Created by opfic on 8/30/26.
//

import Cradle

// Factory가 반환해야 하는 계약
protocol RequiredRepository {}

// 반환 계약을 준수하지 않는 구현
struct NonconformingRepository {}

// 매크로 확장 이후 컴파일러의 적합성 검사 확인용 그래프
@DependencyGraph
final class NonconformingGraph {
	// 프로토콜에 맞지 않는 값을 반환하는 Factory
	@Provide
	private func makeRequiredRepository() -> any RequiredRepository {
		NonconformingRepository()
	}
}
