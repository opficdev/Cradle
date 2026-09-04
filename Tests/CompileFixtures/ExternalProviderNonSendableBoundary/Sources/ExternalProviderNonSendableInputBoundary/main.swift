import Cradle

// actor 경계를 통과할 수 없는 호출자 입력
final class ExternalProviderNonSendableInput {
	// 전송 뒤 호출자가 다시 접근할 값
	var value = 0
}

// actor 경계를 통과할 수 있는 생성 결과
struct ExternalProviderSendableResult: Sendable {}

// 외부 입력의 actor 경계를 확인할 graph
@DependencyGraph
actor ExternalProviderNonSendableInputGraph {
	// 호출자 입력으로 생성 결과 반환
	@Provide(.transient)
	private func makeExternalProviderSendableResult(
		@External input: ExternalProviderNonSendableInput
	) -> ExternalProviderSendableResult {
		_ = input
		return ExternalProviderSendableResult()
	}
}

// actor 밖에서 non-Sendable 입력을 전달해 compiler 오류 유발
func externalProviderNonSendableInputBoundary() async {
	let graph = ExternalProviderNonSendableInputGraph()
	let input = ExternalProviderNonSendableInput()
	_ = await graph.externalProviderSendableResult(input: input)
	_ = input.value
}
