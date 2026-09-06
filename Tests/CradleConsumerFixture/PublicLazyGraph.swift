//
//  PublicLazyGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/6/26.
//

import Cradle

// 외부 module에 노출할 lazy 참조 값
public final class PublicLazyService {
	// 외부 검증값
	public let token: Int

	// 공개 lazy 결과 생성
	public init(token: Int) {
		self.token = token
	}
}

// 외부 module의 public lazy 접근자 검증용 graph
@DependencyGraph
public final class PublicLazyGraph {
	// 외부 graph 생성 허용 initializer
	public init() {}

	// 최초 접근에 생성할 공개 lazy 결과
	@Provide(.lazy)
	private func makePublicLazyService() -> PublicLazyService {
		PublicLazyService(token: 41)
	}
}
