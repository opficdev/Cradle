import Cradle

// shared Factory 상태 참조 여부를 확인할 값
struct ActorGraphSharedValue: Sendable {}

// shared Factory가 actor 상태를 읽을 때 compiler가 거부해야 하는 graph
@DependencyGraph
actor ActorGraphSharedIsolation {
	// shared helper에서 읽으면 안 되는 actor 격리 상태
	private var sequence = 0

	// static helper로 복제될 때 actor 상태 참조 오류를 만드는 shared Factory
	@Provide(.shared)
	private func makeActorGraphSharedValue() -> ActorGraphSharedValue {
		sequence += 1
		return ActorGraphSharedValue()
	}
}
