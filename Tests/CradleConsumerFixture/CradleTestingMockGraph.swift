//
//  CradleTestingMockGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/3/26.
//

import Cradle

// concrete 반환 Factory의 교체 결과
public struct CradleTestingConcreteService: Equatable {
	// concrete 반환 Factory의 검증값
	public let token: Int

	// concrete 반환 Factory의 결과 생성
	public init(token: Int) {
		self.token = token
	}
}

// protocol 반환 Factory의 공개 계약
public protocol CradleTestingRepository {
	// 테스트 대역과 운영 구현을 비교할 값
	var token: Int { get }
}

// protocol 반환 Factory의 원본 구현
public struct CradleTestingLiveRepository: CradleTestingRepository {
	// 원본 구현의 고정 검증값
	public let token: Int

	// 원본 구현 생성
	public init(token: Int) {
		self.token = token
	}
}

// protocol 반환 Factory의 테스트 대역
public struct CradleTestingStubRepository: CradleTestingRepository {
	// 테스트 대역의 검증값
	public let token: Int

	// 테스트 대역 생성
	public init(token: Int) {
		self.token = token
	}
}

// superclass 반환 Factory의 공개 계약
public class CradleTestingRepositoryBase {
	// superclass 반환 Factory의 검증값
	public let token: Int

	// superclass 구현 생성
	public init(token: Int) {
		self.token = token
	}
}

// superclass 반환 Factory의 테스트 대역
public final class CradleTestingRepositorySubclass: CradleTestingRepositoryBase {
	// 테스트 대역 생성
	public init(mockToken: Int) {
		super.init(token: mockToken)
	}
}

// 생략한 override slot의 원본 등록
public struct CradleTestingOriginalService: Equatable {
	// 원본 등록의 고정 검증값
	public let token: Int

	// 원본 등록 생성
	public init(token: Int) {
		self.token = token
	}
}

// XCTest와 Swift Testing이 함께 사용할 override graph
@DependencyGraph(overrides: true)
public final class CradleTestingMockGraph {
	// concrete 결과의 원본 Factory
	@Provide
	private func makeCradleTestingConcreteService() -> CradleTestingConcreteService {
		CradleTestingConcreteService(token: 1)
	}

	// protocol 결과의 원본 Factory
	@Provide
	private func makeCradleTestingRepository() -> any CradleTestingRepository {
		CradleTestingLiveRepository(token: 2)
	}

	// superclass 결과의 원본 Factory
	@Provide
	private func makeCradleTestingRepositoryBase() -> CradleTestingRepositoryBase {
		CradleTestingRepositoryBase(token: 3)
	}

	// 생략한 slot의 원본 Factory
	@Provide
	private func makeCradleTestingOriginalService() -> CradleTestingOriginalService {
		CradleTestingOriginalService(token: 4)
	}
}
