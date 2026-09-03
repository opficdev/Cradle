//
//  PublicTypedOverrideGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/3/26.
//

import Cradle

// 외부 소비자가 교체할 public graph 결과
public struct PublicTypedOverrideService: Equatable {
	// 외부 검증값
	public let value: Int

	// 외부 교체 Factory 생성 허용 initializer
	public init(value: Int) {
		self.value = value
	}
}

// 외부 module에서 override builder를 호출할 public graph
@DependencyGraph(overrides: true)
public final class PublicTypedOverrideGraph {
	@Provide
	private func makePublicTypedOverrideService() -> PublicTypedOverrideService {
		PublicTypedOverrideService(value: 3)
	}
}

// source graph 인자를 받는 외부 override builder 확인용 public graph
@DependencyGraph(sources: [PublicSourceGraph.self], overrides: true)
public final class PublicTypedOverrideSourceGraph: PublicSourceFeatureProviding {
	@Provide
	private func makePublicSourceService() -> PublicSourceService {
		publicSourceGraph.publicSourceService
	}
}

// MainActor 경계를 유지할 외부 override builder 확인용 public graph
@MainActor
@DependencyGraph(overrides: true)
public final class PublicMainActorTypedOverrideGraph {
	@Provide
	private func makePublicTypedOverrideService() -> PublicTypedOverrideService {
		PublicTypedOverrideService(value: 7)
	}
}
