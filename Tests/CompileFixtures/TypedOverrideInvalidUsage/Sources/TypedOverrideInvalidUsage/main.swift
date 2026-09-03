import Cradle

struct TypedOverrideFixtureService: Sendable {}
struct TypedOverrideFixtureInput: Sendable {}
final class TypedOverrideNonSendableCapture {}

@DependencyGraph(overrides: true)
final class TypedOverrideFixtureGraph {
	@Provide
	private func makeTypedOverrideFixtureService() -> TypedOverrideFixtureService {
		TypedOverrideFixtureService()
	}
}

@DependencyGraph(overrides: true)
actor TypedOverrideFixtureActorGraph {
	@Provide
	private func makeTypedOverrideFixtureService() -> TypedOverrideFixtureService {
		TypedOverrideFixtureService()
	}
}

@DependencyGraph(overrides: true)
final class TypedOverrideFixtureInitializerGraph {
	init() {}
}

@DependencyGraph(overrides: true)
final class TypedOverrideFixtureStoredPropertyGraph {
	private let value: Int
}

@DependencyGraph(overrides: true)
final class TypedOverrideFixtureCollisionGraph {
	static func `override`() {}
}

let duplicateLabelGraph = TypedOverrideFixtureGraph.override(
	typedOverrideFixtureService: .factory {
		TypedOverrideFixtureService()
	},
	typedOverrideFixtureService: .factory {
		TypedOverrideFixtureService()
	}
).build()

let wrongParameterGraph = TypedOverrideFixtureGraph.override(
	typedOverrideFixtureService: .factory { (_: TypedOverrideFixtureInput) in
		TypedOverrideFixtureService()
	}
).build()

let wrongResultGraph = TypedOverrideFixtureGraph.override(
	typedOverrideFixtureService: .factory {
		0
	}
).build()

func makeActorCaptureGraph() {
	let capture = TypedOverrideNonSendableCapture()
	_ = TypedOverrideFixtureActorGraph.override(
		typedOverrideFixtureService: .factory {
			_ = capture
			return TypedOverrideFixtureService()
		}
	).build()
}

@DependencyGraph(overrides: true)
final class TypedOverrideFixtureParameterizedGraph {
	@Provide
	private func makeTypedOverrideFixtureInput() -> TypedOverrideFixtureInput {
		TypedOverrideFixtureInput()
	}

	@Provide
	private func makeTypedOverrideFixtureService(
		input: TypedOverrideFixtureInput
	) -> TypedOverrideFixtureService {
		_ = input
		return TypedOverrideFixtureService()
	}
}

let wrongParameterTypeGraph = TypedOverrideFixtureParameterizedGraph.override(
	typedOverrideFixtureService: .factory { (_: Int) in
		TypedOverrideFixtureService()
	}
).build()
