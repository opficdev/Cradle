import Cradle
import CradleTesting

struct CradleTestingFixtureService: Sendable {}
struct CradleTestingFixtureInput: Sendable {}
final class CradleTestingNonSendableCapture {}

@DependencyGraph(overrides: true)
final class CradleTestingFixtureGraph {
	@Provide
	private func makeCradleTestingFixtureService() -> CradleTestingFixtureService {
		CradleTestingFixtureService()
	}
}

@DependencyGraph(overrides: true)
actor CradleTestingFixtureActorGraph {
	@Provide
	private func makeCradleTestingFixtureService() -> CradleTestingFixtureService {
		CradleTestingFixtureService()
	}
}

@DependencyGraph(overrides: true)
final class CradleTestingFixtureParameterizedGraph {
	@Provide
	private func makeCradleTestingFixtureInput() -> CradleTestingFixtureInput {
		CradleTestingFixtureInput()
	}

	@Provide
	private func makeCradleTestingFixtureService(
		input: CradleTestingFixtureInput
	) -> CradleTestingFixtureService {
		_ = input
		return CradleTestingFixtureService()
	}
}

let unknownLabelGraph = CradleTestingFixtureGraph.override(
	unknown: .mock {
		CradleTestingFixtureService()
	}
).build()

let duplicateLabelGraph = CradleTestingFixtureGraph.override(
	cradleTestingFixtureService: .mock {
		CradleTestingFixtureService()
	},
	cradleTestingFixtureService: .mock {
		CradleTestingFixtureService()
	}
).build()

let wrongParameterGraph = CradleTestingFixtureGraph.override(
	cradleTestingFixtureService: .mock { (_: CradleTestingFixtureInput) in
		CradleTestingFixtureService()
	}
).build()

let wrongResultGraph = CradleTestingFixtureGraph.override(
	cradleTestingFixtureService: .mock {
		0
	}
).build()

func makeActorCaptureGraph() {
	let capture = CradleTestingNonSendableCapture()
	_ = CradleTestingFixtureActorGraph.override(
		cradleTestingFixtureService: .mock {
			_ = capture
			return CradleTestingFixtureService()
		}
	).build()
}

let wrongParameterTypeGraph = CradleTestingFixtureParameterizedGraph.override(
	cradleTestingFixtureService: .mock { (_: Int) in
		CradleTestingFixtureService()
	}
).build()
