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

// Swift Testing에서 외부 입력 mock Factory의 전체 매개변수 전달 확인
@Test
func externalProviderOverrideMockSupportsExternalInput() {
	let graph = CradleTestingMockGraph.override(
		cradleTestingExternalResult: .mock { service, input in
			CradleTestingExternalResult(token: service.token * input)
		}
	).build()
	let result = graph.cradleTestingExternalResult(input: 3)

	#expect(result.token == 3)
}

// mock Factory 호출 횟수 확인용 참조 값
private final class CradleTestingMockFactoryProbe {
	// shared mock Factory 호출 횟수
	var sharedCount = 0
	// transient mock Factory 호출 횟수
	var transientCount = 0
}

// shared와 transient mock Factory의 평가 시점과 graph별 수명 확인
@Test
func cradleTestingSwiftTestingPreservesMockFactoryLifetimes() {
	let probe = CradleTestingMockFactoryProbe()
	let builder = CradleTestingLifetimeGraph.override(
		cradleTestingSharedService: .mock {
			probe.sharedCount += 1
			return CradleTestingSharedService(token: probe.sharedCount)
		},
		cradleTestingTransientService: .mock { shared in
			probe.transientCount += 1
			return CradleTestingTransientService(shared: shared)
		}
	)

	#expect(probe.sharedCount == 0)
	#expect(probe.transientCount == 0)
	let first = builder.build()
	let second = builder.build()

	#expect(probe.sharedCount == 2)
	#expect(probe.transientCount == 0)
	#expect(first.cradleTestingSharedService !== second.cradleTestingSharedService)
	let firstTransient = first.cradleTestingTransientService
	let secondTransient = first.cradleTestingTransientService

	#expect(probe.transientCount == 2)
	#expect(firstTransient.shared === first.cradleTestingSharedService)
	#expect(secondTransient.shared === first.cradleTestingSharedService)
}

// 병렬 actor graph의 shared 참조와 검증값
private struct CradleTestingActorGraphResult: Sendable {
	// graph별 mock Factory의 검증값
	let token: Int
	// graph가 보관한 shared 참조 값
	let shared: CradleTestingActorSharedService
	// 한 graph 안의 shared 재사용 여부
	let reusesShared: Bool
}

// 병렬 actor graph가 override와 shared 참조를 공유하지 않는지 확인
@Test
func cradleTestingSwiftTestingSeparatesParallelActorGraphs() async {
	let tokens = [31, 32, 33]
	let results = await withTaskGroup(
		of: CradleTestingActorGraphResult.self,
		returning: [CradleTestingActorGraphResult].self
	) { group in
		for token in tokens {
			group.addTask {
				let graph = CradleTestingActorMockGraph.override(
					cradleTestingActorSharedService: .mock {
						CradleTestingActorSharedService(token: token)
					}
				).build()
				let first = await graph.cradleTestingActorTransientService
				let second = await graph.cradleTestingActorTransientService

				return CradleTestingActorGraphResult(
					token: token,
					shared: first.shared,
					reusesShared: first.shared === second.shared
				)
			}
		}
		var results = [CradleTestingActorGraphResult]()
		for await result in group {
			results.append(result)
		}
		return results
	}

	#expect(results.count == tokens.count)
	for result in results {
		#expect(result.reusesShared)
		#expect(await result.shared.token == result.token)
	}
	for index in results.indices {
		for other in results.dropFirst(index + 1) {
			#expect(results[index].shared !== other.shared)
		}
	}
}
