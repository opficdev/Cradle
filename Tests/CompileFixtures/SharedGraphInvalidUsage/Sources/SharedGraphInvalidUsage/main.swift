import Cradle

struct SharedGraphInvalidService: Sendable {}
final class SharedGraphInvalidCapture {}
final class SharedGraphInvalidNonSendableService {}

@DependencyGraph(.shared)
final class SharedGraphMissingSendable {}

@DependencyGraph(.shared)
final class SharedGraphUnchecked: @unchecked Sendable {}

@DependencyGraph(.shared)
final class SharedGraphLazy: Sendable {
	@Provide(.lazy)
	private func makeSharedGraphInvalidService() -> SharedGraphInvalidService {
		SharedGraphInvalidService()
	}
}

@DependencyGraph(.shared)
final class SharedGraphNonSendableProvider: Sendable {
	@Provide
	private func makeSharedGraphInvalidNonSendableService() -> SharedGraphInvalidNonSendableService {
		SharedGraphInvalidNonSendableService()
	}
}

@DependencyGraph
final class SharedGraphInstanceSource: Sendable {}

@DependencyGraph(.shared, sources: [SharedGraphInstanceSource.self])
final class SharedGraphMissingSourceStatic: Sendable {}

struct SharedGraphWrongStaticValue: Sendable {}

final class SharedGraphWrongStaticSource: Sendable {
	static let shared = SharedGraphWrongStaticValue()
}

@DependencyGraph(.shared, sources: [SharedGraphWrongStaticSource.self])
final class SharedGraphWrongStaticFeature: Sendable {}

final class SharedGraphPrivateSource: Sendable {
	private static let shared = SharedGraphPrivateSource()
}

@DependencyGraph(.shared, sources: [SharedGraphPrivateSource.self])
final class SharedGraphPrivateSourceFeature: Sendable {}

@MainActor
final class SharedGraphMainActorSource {
	static let shared = SharedGraphMainActorSource()
}

@DependencyGraph(.shared, sources: [SharedGraphMainActorSource.self])
final class SharedGraphMainActorSourceFeature: Sendable {}

final class SharedGraphNonSendableSource {
	static let shared = SharedGraphNonSendableSource()
}

@DependencyGraph(.shared, sources: [SharedGraphNonSendableSource.self])
final class SharedGraphNonSendableSourceFeature: Sendable {}

final class SharedGraphActorNonSendableService {}

@DependencyGraph(.shared)
actor SharedGraphInvalidActor {
	@Provide
	private func makeSharedGraphActorNonSendableService() -> SharedGraphActorNonSendableService {
		SharedGraphActorNonSendableService()
	}
}

func sharedGraphInvalidActorConsumption() async -> SharedGraphActorNonSendableService {
	await SharedGraphInvalidActor.shared.sharedGraphActorNonSendableService
}

@DependencyGraph(.shared, overrides: true)
final class SharedGraphOverride: Sendable {
	@Provide
	private func makeSharedGraphInvalidService() -> SharedGraphInvalidService {
		SharedGraphInvalidService()
	}
}

func sharedGraphInvalidOverrideCapture() {
	let capture = SharedGraphInvalidCapture()
	_ = SharedGraphOverride.override(
		sharedGraphInvalidService: .replace {
			_ = capture
			return SharedGraphInvalidService()
		}
	)
}
