//
//  PublicGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 8/29/26.
//

import Cradle

// 외부 module에서 생성할 수 있는 service
public struct PublicService {
	// 외부 생성 허용 initializer
	public init() {}
}

// 외부 소비 graph의 public 접근자 검증용 graph
@DependencyGraph
public final class PublicGraph {
	// 외부 graph 생성 허용 initializer
	public init() {}

	// public 생성 접근자가 호출할 private factory
	@Provide
	private func makePublicService() -> PublicService {
		PublicService()
	}
}
