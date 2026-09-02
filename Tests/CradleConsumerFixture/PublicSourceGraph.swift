//
//  PublicSourceGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/2/26.
//

import Cradle

// 외부 소비자에게 공개할 source graph 결과
public struct PublicSourceService: Equatable {
	// 외부 소비자 확인용 값
	public let token: Int

	// 외부 소비자 생성 허용 initializer
	public init(token: Int) {
		self.token = token
	}
}

// 외부 소비자에게 공개할 source graph
@DependencyGraph
public final class PublicSourceGraph {
	// 외부 소비자 생성 허용 initializer
	public init() {}

	// 조합 graph가 읽을 공개 결과 생성
	@Provide
	private func makePublicSourceService() -> PublicSourceService {
		PublicSourceService(token: 64)
	}
}

// protocol만 채택한 조합 graph의 외부 접근자 형태
public protocol PublicSourceFeatureProviding {
	var publicSourceService: PublicSourceService { get }
}

// source graph 결과를 직접 조합해 외부에 공개할 graph
@DependencyGraph(sources: [PublicSourceGraph.self])
public final class PublicSourceFeatureGraph: PublicSourceFeatureProviding {
	@Provide
	private func makePublicSourceFeature() -> PublicSourceService {
		publicSourceGraph.publicSourceService
	}
}
