//
//  CradleTestingSwiftTestingSupportTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import CradleConsumerFixture
import CradleTesting
import Testing

// Swift Testing에서 concrete·protocol·superclass mock Factory와 원본 slot을 확인
@Test
func cradleTestingSwiftTestingSupportsMockFactoryContracts() {
	let graph = CradleTestingMockGraph.override(
		cradleTestingConcreteService: .mock {
			CradleTestingConcreteService(token: 11)
		},
		cradleTestingRepository: .mock {
			CradleTestingStubRepository(token: 12)
		},
		cradleTestingRepositoryBase: .mock {
			CradleTestingRepositorySubclass(mockToken: 13)
		}
	).build()

	#expect(graph.cradleTestingConcreteService.token == 11)
	#expect(graph.cradleTestingRepository.token == 12)
	#expect(graph.cradleTestingRepositoryBase.token == 13)
	#expect(graph.cradleTestingRepositoryBase is CradleTestingRepositorySubclass)
	#expect(graph.cradleTestingOriginalService.token == 4)
}
