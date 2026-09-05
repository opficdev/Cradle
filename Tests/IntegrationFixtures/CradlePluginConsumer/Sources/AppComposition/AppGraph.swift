import Cradle

@DependencyGraph
final class AppGraph {
	@Provide
	private func makeRepository() -> Repository {
		Repository()
	}

	@Provide(.transient)
	private func makeFeature(repository: Repository) -> Feature {
		Feature(repository: repository)
	}
}

@DependencyGraph(diagram: false)
final class ExcludedGraph {
	@Provide
	private func makeExcludedFeature() -> ExcludedFeature {
		ExcludedFeature()
	}
}

@Cradle.DependencyGraph(diagram: true)
final class ExplicitGraph {}

@DependencyGraph
final class ExternalGraph {
	@Provide(.transient)
	private func makeExternalFeature(@External id: Int) -> ExternalFeature {
		ExternalFeature(id: id)
	}
}

enum Composition {
	@DependencyGraph
	final class NestedGraph {
		@Provide
		private func makeNestedFeature() -> NestedFeature {
			NestedFeature()
		}
	}
}

struct ExtensionFeatureA {}

extension ExtensionFeatureA {
	@DependencyGraph
	final class AppGraph {
		@Provide
		private func makeExtensionFeature() -> ExtensionFeature {
			ExtensionFeature()
		}
	}
}

struct ExtensionFeatureB {}

extension ExtensionFeatureB {
	@DependencyGraph
	final class AppGraph {
		@Provide
		private func makeExtensionFeature() -> ExtensionFeature {
			ExtensionFeature()
		}
	}
}

struct Repository {}

struct Feature {
	let repository: Repository
}

struct ExcludedFeature {}

struct ExplicitFeature {}

struct ExternalFeature {
	let id: Int
}

struct NestedFeature {}

struct ExtensionFeature {}
