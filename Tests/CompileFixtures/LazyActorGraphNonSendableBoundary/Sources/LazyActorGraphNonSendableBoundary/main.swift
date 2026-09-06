import Cradle

final class LazyActorNonSendableService {}

// actor 안에서는 허용하되 밖으로 반환할 수 없는 lazy 등록 graph
@DependencyGraph
actor LazyActorGraphNonSendableBoundary {
	@Provide(.lazy)
	private func makeLazyActorNonSendableService() -> LazyActorNonSendableService {
		LazyActorNonSendableService()
	}
}

// actor 밖에서 non-Sendable lazy 결과를 읽는 오류 확인
func readLazyActorService(
	from graph: LazyActorGraphNonSendableBoundary
) async -> LazyActorNonSendableService {
	await graph.lazyActorNonSendableService
}

// actor-isolated lazy 생성 프로퍼티를 await 없이 읽는 오류 확인
func readLazyActorServiceSynchronously(
	from graph: LazyActorGraphNonSendableBoundary
) -> LazyActorNonSendableService {
	graph.lazyActorNonSendableService
}
