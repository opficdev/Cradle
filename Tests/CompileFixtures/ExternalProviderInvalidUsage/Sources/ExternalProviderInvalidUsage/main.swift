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
