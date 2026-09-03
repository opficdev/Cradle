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
	typedOverrideFixtureService: .replace {
		TypedOverrideFixtureService()
	},
	typedOverrideFixtureService: .replace {
		TypedOverrideFixtureService()
	}
).build()

let wrongParameterGraph = TypedOverrideFixtureGraph.override(
	typedOverrideFixtureService: .replace { (_: TypedOverrideFixtureInput) in
		TypedOverrideFixtureService()
	}
).build()

let wrongResultGraph = TypedOverrideFixtureGraph.override(
	typedOverrideFixtureService: .replace {
		0
	}
).build()

func makeActorCaptureGraph() {
	let capture = TypedOverrideNonSendableCapture()
	_ = TypedOverrideFixtureActorGraph.override(
		typedOverrideFixtureService: .replace {
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
	typedOverrideFixtureService: .replace { (_: Int) in
		TypedOverrideFixtureService()
	}
).build()
