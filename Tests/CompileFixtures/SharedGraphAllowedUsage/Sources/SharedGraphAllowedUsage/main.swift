import Cradle

// shared source graph와 조합 graph가 함께 보관할 값
struct SharedGraphAllowedService: Sendable {}

// 비격리 checked Sendable source graph
@DependencyGraph(.shared)
final class SharedGraphAllowedSource: Sendable {
	@Provide
	private func makeSharedGraphAllowedService() -> SharedGraphAllowedService {
		SharedGraphAllowedService()
	}
}

// source graph의 정확한 정적 타입을 받는 조합 graph
@DependencyGraph(.shared, sources: [SharedGraphAllowedSource.self])
final class SharedGraphAllowedFeature: Sendable {
	@Provide
	private func makeSharedGraphAllowedFeature() -> SharedGraphAllowedService {
		sharedGraphAllowedSource.sharedGraphAllowedService
	}
}

// source 저장 이름과 겹칠 수 있는 type 경로를 확인할 namespace
// swiftlint:disable:next type_name
enum sharedGraphAllowedSource {
	@DependencyGraph(.shared)
	final class Source: Sendable {}
}

// source 저장 이름과 type 경로가 겹쳐도 조합하는 graph
@DependencyGraph(
	.shared,
	sources: [SharedGraphAllowedSource.self, sharedGraphAllowedSource.Source.self]
)
final class SharedGraphAllowedQualifiedFeature: Sendable {}

// 사용자가 명시한 MainActor 격리 graph
@MainActor
@DependencyGraph(.shared)
final class SharedGraphAllowedMainActor {}

// actor graph의 정적 접근점
@DependencyGraph(.shared)
actor SharedGraphAllowedActor {}

// provider가 없어도 Sendable builder를 유지할 actor graph
@DependencyGraph(.shared, overrides: true)
public actor SharedGraphAllowedEmptyActor {}

// provider가 없어도 Sendable builder를 유지할 checked Sendable class graph
@DependencyGraph(.shared, overrides: true)
public final class SharedGraphAllowedEmptyClass: Sendable {}

// package 접근 수준을 보존할 shared graph
@DependencyGraph(.shared)
package final class SharedGraphAllowedPackage: Sendable {}

func requireSharedGraphAllowedSendable<Value: Sendable>(_ value: Value) {}

// source·조합 graph의 정적 타입 접근 확인
@MainActor
func sharedGraphAllowedUsage() {
	let source: SharedGraphAllowedSource = .shared
	let feature: SharedGraphAllowedFeature = .shared
	_ = source
	_ = feature
	_ = SharedGraphAllowedMainActor.shared
	_ = SharedGraphAllowedActor.shared
	_ = SharedGraphAllowedQualifiedFeature.shared
	_ = SharedGraphAllowedPackage.shared
	requireSharedGraphAllowedSendable(SharedGraphAllowedEmptyActor.override())
	requireSharedGraphAllowedSendable(SharedGraphAllowedEmptyClass.override())
}
