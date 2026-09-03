//
//  MainActorGraphTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Cradle
import Testing

// MainActor graph가 공유할 참조 값
final class MainActorSharedService {}

// MainActor override 결과 확인용 참조 값
final class MainActorTypedOverrideService {
	// 교체 결과 검증값
	let value: Int

	init(value: Int) {
		self.value = value
	}
}

// MainActor graph가 매번 새로 만들 결과
struct MainActorTransientService {
	// shared 수명 보존 여부를 확인할 의존성
	let shared: MainActorSharedService
}

// 기존 class graph 격리를 보존할 MainActor graph
@MainActor
@DependencyGraph
final class MainActorDependencyGraph {
	// graph별로 한 번만 보관할 shared service 생성
	@Provide(.shared)
	private func makeMainActorSharedService() -> MainActorSharedService {
		MainActorSharedService()
	}

	// shared service를 받아 매번 새 결과를 만들 transient service 생성
	@Provide(.transient)
	private func makeMainActorTransientService(
		shared: MainActorSharedService
	) -> MainActorTransientService {
		MainActorTransientService(shared: shared)
	}
}

// MainActor 격리 builder 생성 경로 확인용 graph
@_Concurrency.`MainActor`
@DependencyGraph(overrides: true)
final class MainActorTypedOverrideGraph {
	@Provide
	private func makeMainActorTypedOverrideService() -> MainActorTypedOverrideService {
		MainActorTypedOverrideService(value: 8)
	}
}

// MainActor class graph의 shared와 transient 생성 계약 회귀 확인
@Test
@MainActor
func mainActorGraphPreservesClassGraphLifetimes() {
	let graph = MainActorDependencyGraph()
	let first = graph.mainActorTransientService
	let second = graph.mainActorTransientService

	#expect(first.shared === second.shared)
	#expect(first.shared === graph.mainActorSharedService)
}

// MainActor에서 override builder와 build를 함께 호출하는지 확인
@Test
@MainActor
func mainActorTypedOverrideGraphBuildsOnMainActor() {
	let graph = MainActorTypedOverrideGraph.override(
		mainActorTypedOverrideService: .factory {
			MainActorTypedOverrideService(value: 15)
		}
	).build()

	#expect(graph.mainActorTypedOverrideService.value == 15)
}
