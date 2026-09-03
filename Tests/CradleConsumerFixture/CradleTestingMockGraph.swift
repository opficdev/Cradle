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

// mock Factory의 graph별 수명을 확인할 shared 참조 값
public final class CradleTestingSharedService {
	// shared Factory의 검증값
	public let token: Int

	// shared 참조 값 생성
	public init(token: Int) {
		self.token = token
	}
}

// shared 의존성을 받는 transient 결과
public struct CradleTestingTransientService {
	// transient 결과에 주입한 shared 참조 값
	public let shared: CradleTestingSharedService

	// transient 결과 생성
	public init(shared: CradleTestingSharedService) {
		self.shared = shared
	}
}

// shared·transient mock Factory의 평가 시점을 확인할 graph
@DependencyGraph(overrides: true)
public final class CradleTestingLifetimeGraph {
	// shared 결과의 원본 Factory
	@Provide
	private func makeCradleTestingSharedService() -> CradleTestingSharedService {
		CradleTestingSharedService(token: 5)
	}

	// transient 결과의 원본 Factory
	@Provide(.transient)
	private func makeCradleTestingTransientService(
		shared: CradleTestingSharedService
	) -> CradleTestingTransientService {
		CradleTestingTransientService(shared: shared)
	}
}

// 병렬 actor graph의 graph별 shared 참조 값
public actor CradleTestingActorSharedService {
	// actor shared Factory의 검증값
	public let token: Int

	// actor shared 참조 값 생성
	public init(token: Int) {
		self.token = token
	}
}

// actor graph가 생성할 transient 결과
public struct CradleTestingActorTransientService: Sendable {
	// actor graph가 보관한 shared 참조 값
	public let shared: CradleTestingActorSharedService

	// actor transient 결과 생성
	public init(shared: CradleTestingActorSharedService) {
		self.shared = shared
	}
}

// 병렬 mock 구성을 확인할 actor graph
@DependencyGraph(overrides: true)
public actor CradleTestingActorMockGraph {
	// actor shared 결과의 원본 Factory
	@Provide
	private func makeCradleTestingActorSharedService() -> CradleTestingActorSharedService {
		CradleTestingActorSharedService(token: 6)
	}

	// actor transient 결과의 원본 Factory
	@Provide(.transient)
	private func makeCradleTestingActorTransientService(
		shared: CradleTestingActorSharedService
	) -> CradleTestingActorTransientService {
		CradleTestingActorTransientService(shared: shared)
	}
}
