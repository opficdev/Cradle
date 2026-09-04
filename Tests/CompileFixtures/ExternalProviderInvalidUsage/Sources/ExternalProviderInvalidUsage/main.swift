import Cradle

struct ExternalProviderInvalidService {}
struct ExternalProviderInvalidProfile {}
struct ExternalProviderInvalidScreen {}

@DependencyGraph
final class ExternalProviderInvalidLifetimeGraph {
	@Provide
	private func makeExternalProviderInvalidService(
		@External id: Int
	) -> ExternalProviderInvalidService {
		ExternalProviderInvalidService()
	}
}

@DependencyGraph
final class ExternalProviderInvalidResultGraph {
	@Provide(.transient)
	private func makeExternalProviderInvalidProfile(
		@External id: Int
	) -> ExternalProviderInvalidProfile {
		ExternalProviderInvalidProfile()
	}

	@Provide(.transient)
	private func makeExternalProviderInvalidScreen(
		profile: ExternalProviderInvalidProfile
	) -> ExternalProviderInvalidScreen {
		ExternalProviderInvalidScreen()
	}
}

@DependencyGraph
final class ExternalProviderInvalidCollisionGraph {
	func externalProviderInvalidService(id: Int) -> ExternalProviderInvalidService {
		ExternalProviderInvalidService()
	}

	@Provide(.transient)
	private func makeExternalProviderInvalidService(
		@External id: Int
	) -> ExternalProviderInvalidService {
		ExternalProviderInvalidService()
	}
}

// 외부 입력과 함께 선언할 수 없는 추가 property wrapper
@propertyWrapper
struct ExternalProviderOtherWrapper<Value> {
	// 원본 입력 값
	let wrappedValue: Value
}

// 추가 property wrapper 진단 검증 graph
@DependencyGraph
final class ExternalProviderInvalidWrapperGraph {
	// 외부 입력과 추가 property wrapper를 함께 선언한 Factory
	@Provide(.transient)
	private func makeExternalProviderInvalidService(
		@External @ExternalProviderOtherWrapper input: Int
	) -> ExternalProviderInvalidService {
		ExternalProviderInvalidService()
	}
}
