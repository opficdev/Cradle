import Cradle

struct ExternalProviderOverrideRepository {}
struct ExternalProviderOverrideResult {}

@DependencyGraph(overrides: true)
final class ExternalProviderOverrideInvalidGraph {
	@Provide
	private func makeExternalProviderOverrideRepository() -> ExternalProviderOverrideRepository {
		ExternalProviderOverrideRepository()
	}

	@Provide(.transient)
	private func makeExternalProviderOverrideResult(
		repository: ExternalProviderOverrideRepository,
		@External id: Int
	) -> ExternalProviderOverrideResult {
		ExternalProviderOverrideResult()
	}
}

let graph = ExternalProviderOverrideInvalidGraph.override(
	externalProviderOverrideResult: .replace { (_: ExternalProviderOverrideRepository) in
		ExternalProviderOverrideResult()
	}
).build()
