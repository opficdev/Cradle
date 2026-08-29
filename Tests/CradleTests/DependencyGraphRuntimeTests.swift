//
//  DependencyGraphRuntimeTests.swift
//  CradleTests
//
//  Created by opfic on 8/29/26.
//

import Cradle
import Foundation
import Testing

// class 반환값 identity 확인용 probe
final class ReferenceProbe {}

// struct 반환값 transient 생성 확인용 probe
struct ValueProbe: Equatable {
	// 각 생성값 구분용 식별자
	let token = UUID()
}

// actor 반환값 identity 확인용 probe
actor ActorProbe {}

// graph 사용자 stored property 전달값 보관
struct ConfigurationValue {
	// graph initializer 수신값 보관
	let token: UUID
}

// G1 transient 생성 경로 동작 검증용 graph
@DependencyGraph
final class RuntimeGraph {
	// 사용자 initializer 보관값
	private let token: UUID
	// class factory 호출 횟수 검증용 보관값
	private(set) var invocationCount = 0

	// graph 필요 사용자 값 저장
	init(token: UUID) {
		self.token = token
	}

	// 매 접근별 새 class probe 생성
	@Provide
	private func makeReferenceProbe() -> ReferenceProbe {
		invocationCount += 1
		return ReferenceProbe()
	}

	// 매 접근별 새 struct probe 생성
	@Provide
	private func makeValueProbe() -> ValueProbe {
		ValueProbe()
	}

	// 매 접근별 새 actor probe 생성
	@Provide
	private func makeActorProbe() -> ActorProbe {
		ActorProbe()
	}

	// 사용자 initializer 값을 담은 configuration 생성
	@Provide
	private func buildConfigurationValue() -> ConfigurationValue {
		ConfigurationValue(token: token)
	}
}

// class factory의 접근 횟수별 새 instance 생성 확인
@Test
func providerCreatesANewClassInstanceForEachAccess() {
	let graph = RuntimeGraph(token: UUID())
	let first = graph.referenceProbe()
	let second = graph.referenceProbe()

	#expect(first !== second)
	#expect(graph.invocationCount == 2)
}

// struct와 actor factory별 새 값 생성 확인
@Test
func providerCreatesNewStructAndActorValuesForEachAccess() {
	let graph = RuntimeGraph(token: UUID())

	#expect(graph.valueProbe() != graph.valueProbe())
	#expect(graph.actorProbe() !== graph.actorProbe())
}

// Macro의 사용자 initializer·stored property 미변경 확인
@Test
func graphKeepsUserInitializerAndStoredProperty() {
	let token = UUID()

	#expect(RuntimeGraph(token: token).configurationValue().token == token)
}
