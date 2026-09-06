//
//  SharedGraphRuntimeTests.swift
//  CradleTests
//
//  Created by opfic on 9/6/26.
//

import Cradle
import Foundation
import Testing

// 정적 source·조합 graph의 조립 순서 기록용 probe
final class SharedGraphRuntimeProbe: @unchecked Sendable {
	static let shared = SharedGraphRuntimeProbe()

	private let lock = NSLock()
	private var events: [String] = []

	func reset() {
		lock.withLock {
			events = []
		}
	}

	func record(_ event: String) {
		lock.withLock {
			events.append(event)
		}
	}

	func snapshot() -> [String] {
		lock.withLock {
			events
		}
	}
}

// 정적 source graph가 제공할 값
struct SharedGraphRuntimeSourceValue: Sendable {
	let value: Int
}

// 정적 source 조립을 확인할 source graph
@DependencyGraph(.shared)
final class SharedGraphRuntimeSource: Sendable {
	@Provide
	private func makeSharedGraphRuntimeSourceValue() -> SharedGraphRuntimeSourceValue {
		SharedGraphRuntimeProbe.shared.record("source")
		return SharedGraphRuntimeSourceValue(value: 1)
	}
}

// 정적 source graph를 조합하는 graph
@DependencyGraph(.shared, sources: [SharedGraphRuntimeSource.self])
final class SharedGraphRuntimeFeature: Sendable {
	@Provide
	private func makeSharedGraphRuntimeFeatureValue() -> Int {
		SharedGraphRuntimeProbe.shared.record("feature")
		return sharedGraphRuntimeSource.sharedGraphRuntimeSourceValue.value
	}
}

// 정적 graph와 독립 override graph의 원본 선택 확인용 graph
@DependencyGraph(.shared, overrides: true)
final class SharedGraphRuntimeOverride: Sendable {
	@Provide
	private func makeSharedGraphRuntimeOverrideValue() -> Int {
		1
	}
}

// static graph identity와 source 정적 접근 뒤 조립 순서 확인
@Test
func sharedGraphReusesStaticIdentityAndBuildsSourcesInOrder() {
	SharedGraphRuntimeProbe.shared.reset()

	let first = SharedGraphRuntimeFeature.shared
	let second = SharedGraphRuntimeFeature.shared

	#expect(first === second)
	#expect(first.int == 1)
	#expect(SharedGraphRuntimeProbe.shared.snapshot() == ["source", "feature"])
}

// shared 접근점은 원본 선택을 사용하고 override graph와 상태를 분리하는지 확인
@Test
func sharedGraphUsesOriginalFactoriesSeparateFromOverrideGraph() {
	let shared = SharedGraphRuntimeOverride.shared
	let override = SharedGraphRuntimeOverride.override(
		int: .replace { 2 }
	).build()

	#expect(shared.int == 1)
	#expect(override.int == 2)
	#expect(SharedGraphRuntimeOverride.shared === shared)
}
