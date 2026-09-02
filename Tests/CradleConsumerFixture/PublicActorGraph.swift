//
//  PublicActorGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/3/26.
//

import Cradle

// 외부 actor 경계를 통과할 public actor 등록
public actor PublicActorService {
	// 외부 service 생성 허용 initializer
	public init() {}

	// 외부 소비자 확인용 고정 값 반환
	public func token() -> Int {
		21
	}
}

// 외부 module의 await 생성 접근자 검증용 actor graph
@DependencyGraph
public actor PublicActorGraph {
	// 외부 graph 생성 허용 initializer
	public init() {}

	// public actor 생성 접근자가 반환할 actor service 생성
	@Provide(.shared)
	private func makePublicActorService() -> PublicActorService {
		PublicActorService()
	}
}
