//
//  PublicProtocolGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 8/30/26.
//

import Cradle

// 외부 소비자에게 공개할 계약
public protocol PublicRepository {
	// 구현이 제공하는 검증값
	var token: Int { get }
}

// 외부에 공개하지 않을 구현
struct InternalRepository: PublicRepository {
	// 공개 계약으로 전달할 값
	let token = 42
}

// 구현 타입을 숨기고 프로토콜 접근자만 공개할 그래프
@DependencyGraph
public final class PublicProtocolGraph {
	// 외부 모듈에서 그래프 생성 허용
	public init() {}

	// 비공개 구현을 공개 계약으로 반환
	@Provide(.transient)
	private func makePublicRepository() -> any PublicRepository {
		InternalRepository()
	}
}
