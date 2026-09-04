import Cradle

// actor 경계를 통과할 수 없는 생성 결과
final class ExternalProviderNonSendableResult {}

// 생성 결과의 actor 경계를 확인할 graph
@DependencyGraph
actor ExternalProviderNonSendableResultGraph {
	// 호출자 입력으로 non-Sendable 결과 반환
	@Provide(.transient)
	private func makeExternalProviderNonSendableResult(
		@External input: Int
	) -> ExternalProviderNonSendableResult {
		_ = input
		return ExternalProviderNonSendableResult()
	}
}

// actor 밖에서 non-Sendable 생성 결과를 받아 compiler 오류 유발
func externalProviderNonSendableResultBoundary() async {
	let graph = ExternalProviderNonSendableResultGraph()
	_ = await graph.externalProviderNonSendableResult(input: 29)
}
