//
//  CradleTestingXCTestSupportTests.swift
//  CradleTestingXCTests
//
//  Created by opfic on 9/3/26.
//

import CradleConsumerFixture
import CradleTesting
import XCTest

// XCTest에서 concrete·protocol·superclass mock Factory와 원본 slot을 확인
final class CradleTestingXCTestSupportTests: XCTestCase {
	// 같은 graph 계약의 테스트 대역 교체 확인
	func testMockFactoryContracts() {
		let graph = CradleTestingMockGraph.override(
			cradleTestingConcreteService: .mock {
				CradleTestingConcreteService(token: 21)
			},
			cradleTestingRepository: .mock {
				CradleTestingStubRepository(token: 22)
			},
			cradleTestingRepositoryBase: .mock {
				CradleTestingRepositorySubclass(mockToken: 23)
			}
		).build()

		XCTAssertEqual(graph.cradleTestingConcreteService.token, 21)
		XCTAssertEqual(graph.cradleTestingRepository.token, 22)
		XCTAssertEqual(graph.cradleTestingRepositoryBase.token, 23)
		XCTAssertTrue(graph.cradleTestingRepositoryBase is CradleTestingRepositorySubclass)
		XCTAssertEqual(graph.cradleTestingOriginalService.token, 4)
	}

	// 외부 입력 mock Factory의 graph 의존성과 호출자 입력 전달 확인
	func testExternalProviderOverrideMockFactory() {
		let graph = CradleTestingMockGraph.override(
			cradleTestingExternalResult: .mock { service, input in
				CradleTestingExternalResult(token: service.token * input)
			}
		).build()
		let result = graph.cradleTestingExternalResult(input: 5)

		XCTAssertEqual(result.token, 5)
	}
}
