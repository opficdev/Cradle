//
//  PublicExternalProviderGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/4/26.
//

import Cradle

// 외부 모듈에서 생성 메서드에 전달할 공개 입력
public struct PublicExternalProviderInput: Sendable {
	// 외부 소비자 검증값
	public let value: Int

	// 외부 소비자 입력 생성
	public init(value: Int) {
		self.value = value
	}
}

// 외부 모듈에서 생성 메서드 결과로 받을 공개 값
public struct PublicExternalProviderService: Sendable {
	// 생성 메서드가 전달한 검증값
	public let value: Int
}

// 외부 모듈에서 `@External` 생성 메서드를 호출할 공개 graph
@DependencyGraph
public final class PublicExternalProviderGraph {
	// 외부 모듈의 graph 생성 허용 initializer
	public init() {}

	// 호출자가 전달한 입력으로 공개 결과 생성
	@Provide(.transient)
	private func makePublicExternalProviderService(
		@Cradle.External input: PublicExternalProviderInput
	) -> PublicExternalProviderService {
		PublicExternalProviderService(value: input.value)
	}
}

// 외부 모듈에서 `await`로 생성 메서드를 호출할 공개 actor graph
@DependencyGraph
public actor PublicExternalProviderActorGraph {
	// 외부 모듈의 actor graph 생성 허용 initializer
	public init() {}

	// 호출자가 전달한 Sendable 입력으로 공개 결과 생성
	@Provide(.transient)
	private func makePublicExternalProviderService(
		@External input: PublicExternalProviderInput
	) -> PublicExternalProviderService {
		PublicExternalProviderService(value: input.value)
	}
}

// 외부 모듈에서 MainActor 생성 메서드를 호출할 공개 graph
@MainActor
@DependencyGraph
public final class PublicExternalProviderMainActorGraph {
	// 외부 모듈의 MainActor graph 생성 허용 initializer
	public init() {}

	// MainActor에서 호출자가 전달한 입력으로 공개 결과 생성
	@Provide(.transient)
	private func makePublicExternalProviderService(
		@External input: PublicExternalProviderInput
	) -> PublicExternalProviderService {
		PublicExternalProviderService(value: input.value)
	}
}
