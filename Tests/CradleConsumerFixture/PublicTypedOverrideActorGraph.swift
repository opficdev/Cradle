//
//  PublicTypedOverrideActorGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/3/26.
//

import Cradle

// 외부 소비자가 교체할 public actor graph 결과
public actor PublicTypedOverrideActorService {
	// 외부 검증값
	private let value: Int

	// 외부 교체 Factory 생성 허용 initializer
	public init(value: Int) {
		self.value = value
	}

	// 외부 actor 경계 확인용 값 반환
	public func token() -> Int {
		value
	}
}

// 외부 module에서 Sendable override builder를 호출할 public actor graph
@DependencyGraph(overrides: true)
public actor PublicTypedOverrideActorGraph {
	@Provide
	private func makePublicTypedOverrideActorService() -> PublicTypedOverrideActorService {
		PublicTypedOverrideActorService(value: 5)
	}
}
