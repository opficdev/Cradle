import Cradle

// Sendable override Factory가 붙잡을 수 없는 참조 값
final class ExternalProviderNonSendableCapture {}

// actor override Factory에 연결할 graph 의존성
struct ExternalProviderOverrideDependency: Sendable {}

// actor override Factory가 반환할 결과
struct ExternalProviderOverrideResult: Sendable {}

// 외부 입력 override Factory의 Sendable 형식 확인용 actor graph
@DependencyGraph(overrides: true)
actor ExternalProviderOverrideActorGraph {
	// override Factory에 전달할 graph 의존성 생성
	@Provide
	private func makeExternalProviderOverrideDependency() -> ExternalProviderOverrideDependency {
		ExternalProviderOverrideDependency()
	}

	// graph 의존성과 외부 입력으로 원본 결과 생성
	@Provide(.transient)
	private func makeExternalProviderOverrideResult(
		dependency: ExternalProviderOverrideDependency,
		@External input: Int
	) -> ExternalProviderOverrideResult {
		_ = dependency
		_ = input
		return ExternalProviderOverrideResult()
	}
}

// actor override의 Sendable Factory에 non-Sendable 값을 capture해 compiler 오류 유발
func externalProviderOverrideNonSendableCapture() {
	let capture = ExternalProviderNonSendableCapture()
	_ = ExternalProviderOverrideActorGraph.override(
		externalProviderOverrideResult: .replace { _, _ in
			_ = capture
			return ExternalProviderOverrideResult()
		}
	).build()
}
