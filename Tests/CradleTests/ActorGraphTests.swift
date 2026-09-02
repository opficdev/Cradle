//
//  ActorGraphTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Cradle
import Testing

// actor graph가 공유할 불변 참조 값
final class ActorSharedService: Sendable {}

// actor graph가 매번 새로 만들 transient 결과
struct ActorTransientService: Sendable {
	// 재사용 여부를 확인할 shared 의존성
	let shared: ActorSharedService
	// 생성 횟수를 확인할 actor 내부 순번
	let sequence: Int
}

// shared와 transient 수명을 함께 확인할 actor graph
@DependencyGraph
actor ActorDependencyGraph {
	// transient 생성 횟수를 기록할 actor 격리 상태
	private var transientSequence = 0

	// graph별로 한 번만 보관할 shared service 생성
	@Provide(.shared)
	private func makeActorSharedService() -> ActorSharedService {
		ActorSharedService()
	}

	// shared service를 받아 매번 새 결과를 만들 transient service 생성
	@Provide(.transient)
	private func makeActorTransientService(
		shared: ActorSharedService
	) -> ActorTransientService {
		transientSequence += 1
		return ActorTransientService(shared: shared, sequence: transientSequence)
	}
}

// actor graph가 shared 값을 재사용하고 transient 값을 다시 만드는지 확인
@Test
func actorGraphSeparatesSharedAndTransientLifetimes() async {
	let firstGraph = ActorDependencyGraph()
	let secondGraph = ActorDependencyGraph()
	let firstTransient = await firstGraph.actorTransientService
	let secondTransient = await firstGraph.actorTransientService
	let secondGraphShared = await secondGraph.actorSharedService

	#expect(firstTransient.sequence == 1)
	#expect(secondTransient.sequence == 2)
	#expect(firstTransient.shared === secondTransient.shared)
	#expect(firstTransient.shared !== secondGraphShared)
}
