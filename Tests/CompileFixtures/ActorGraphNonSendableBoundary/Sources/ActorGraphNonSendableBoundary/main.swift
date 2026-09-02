import Cradle

// actor 내부에서만 허용할 non-Sendable 참조 값
final class ActorGraphNonSendableService {}

// non-Sendable 등록의 actor 내부 사용과 외부 반환을 함께 확인할 graph
@DependencyGraph
actor ActorGraphNonSendableBoundary {
	// graph 내부에서만 non-Sendable 등록을 읽는 actor 격리 메서드
	func internalService() -> ActorGraphNonSendableService {
		actorGraphNonSendableService
	}

	// graph가 소유할 non-Sendable 등록 생성
	@Provide(.shared)
	private func makeActorGraphNonSendableService() -> ActorGraphNonSendableService {
		ActorGraphNonSendableService()
	}
}

// actor 밖 non-Sendable 생성 접근자 소비의 compiler 오류 유발
func actorGraphNonSendableBoundary() async {
	let graph = ActorGraphNonSendableBoundary()
	_ = await graph.actorGraphNonSendableService
}
