import Cradle

struct InternalExternalProviderInput {}

public struct PublicExternalProviderResult {
	public init() {}
}

public struct PublicExternalProviderInput {
	public init() {}
}

struct InternalExternalProviderResult {}

@DependencyGraph
public final class PublicExternalProviderLeakGraph {
	public init() {}

	@Provide(.transient)
	private func makePublicExternalProviderResult(
		@External input: InternalExternalProviderInput
	) -> PublicExternalProviderResult {
		PublicExternalProviderResult()
	}
}

@DependencyGraph
public final class PublicExternalProviderResultLeakGraph {
	public init() {}

	@Provide(.transient)
	private func makeInternalExternalProviderResult(
		@External input: PublicExternalProviderInput
	) -> InternalExternalProviderResult {
		InternalExternalProviderResult()
	}
}
