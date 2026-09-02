//
//  ProviderDependencyConnectionTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Cradle
import Foundation
import Testing

// class 의존성 전달과 생성별 identity 확인용 값
final class ConnectedReference: Sendable {
	// graph에서 전달한 값
	let token: UUID

	// 의존성 전달 검증값 보관
	init(token: UUID) {
		self.token = token
	}
}

// class 의존성을 받는 struct 값
struct ConnectedValue: Sendable {
	// 생성 접근자에서 전달된 class 의존성
	let connectedReference: ConnectedReference
}

// struct 의존성을 받는 actor 값
actor ConnectedActor {
	// 생성 접근자에서 전달된 struct 의존성
	let connectedValue: ConnectedValue

	// struct 의존성 저장
	init(connectedValue: ConnectedValue) {
		self.connectedValue = connectedValue
	}
}

// actor 의존성을 받는 최종 값
struct ConnectedRoot {
	// 생성 접근자에서 전달된 actor 의존성
	let connectedActor: ConnectedActor
}

// 두 매개변수의 순서와 transient 분리 확인용 값
struct DirectConnection {
	// 첫 번째 인자로 전달된 class 의존성
	let connectedReference: ConnectedReference
	// 두 번째 인자로 전달된 struct 의존성
	let connectedValue: ConnectedValue
}

// 의존 순서대로 선언한 provider 연결 검증용 graph
@DependencyGraph
final class ProviderDependencyConnectionGraph {
	// 의존성 끝까지 전달할 검증값
	private let token: UUID
	// provider 실제 호출 순서
	private(set) var invocationOrder: [String] = []

	// 의존성 전달 검증값 저장
	init(token: UUID) {
		self.token = token
	}

	// 매 호출마다 새 class 의존성 생성
	@Provide
	private func makeConnectedReference() -> ConnectedReference {
		invocationOrder.append("reference")
		return ConnectedReference(token: token)
	}

	// class 의존성을 받는 struct 생성
	@Provide
	private func makeConnectedValue(connectedReference: ConnectedReference) -> ConnectedValue {
		invocationOrder.append("value")
		return ConnectedValue(connectedReference: connectedReference)
	}

	// struct 의존성을 받는 actor 생성
	@Provide
	private func makeConnectedActor(connectedValue: ConnectedValue) -> ConnectedActor {
		invocationOrder.append("actor")
		return ConnectedActor(connectedValue: connectedValue)
	}

	// actor 의존성을 받는 최종 값 생성
	@Provide
	private func makeConnectedRoot(connectedActor: ConnectedActor) -> ConnectedRoot {
		invocationOrder.append("root")
		return ConnectedRoot(connectedActor: connectedActor)
	}

	// 외부 레이블 생략과 이름 변경을 포함한 직접 연결
	@Provide
	private func makeDirectConnection(
		_ connectedReference: ConnectedReference,
		value connectedValue: ConnectedValue
	) -> DirectConnection {
		invocationOrder.append("direct")
		return DirectConnection(connectedReference: connectedReference, connectedValue: connectedValue)
	}
}

// 의존 순서를 뒤집어 선언한 provider 연결 검증용 graph
@DependencyGraph
final class ReversedDependencyConnectionGraph {
	// 의존성 끝까지 전달할 검증값
	private let token: UUID
	// provider 실제 호출 순서
	private(set) var invocationOrder: [String] = []

	// 의존성 전달 검증값 저장
	init(token: UUID) {
		self.token = token
	}

	// 의존 선언보다 앞에 배치한 최종 값 provider
	@Provide
	private func makeConnectedRoot(connectedActor: ConnectedActor) -> ConnectedRoot {
		invocationOrder.append("root")
		return ConnectedRoot(connectedActor: connectedActor)
	}

	// struct 선언보다 앞에 배치한 actor provider
	@Provide
	private func makeConnectedActor(connectedValue: ConnectedValue) -> ConnectedActor {
		invocationOrder.append("actor")
		return ConnectedActor(connectedValue: connectedValue)
	}

	// class 선언보다 앞에 배치한 struct provider
	@Provide
	private func makeConnectedValue(connectedReference: ConnectedReference) -> ConnectedValue {
		invocationOrder.append("value")
		return ConnectedValue(connectedReference: connectedReference)
	}

	// 의존 순서의 마지막에 배치한 class provider
	@Provide
	private func makeConnectedReference() -> ConnectedReference {
		invocationOrder.append("reference")
		return ConnectedReference(token: token)
	}
}

// 인자 평가 순서와 각 연결의 transient 생성 확인
@Test
func providerDependencyConnectionBuildsDirectEdgesInParameterOrder() {
	// 전달 결과를 비교할 검증값
	let token = UUID()
	// 직접 연결을 생성할 graph
	let graph = ProviderDependencyConnectionGraph(token: token)
	// 외부 레이블이 다른 두 인자를 받는 결과
	let connection = graph.directConnection

	#expect(connection.connectedReference.token == token)
	#expect(connection.connectedValue.connectedReference.token == token)
	#expect(connection.connectedReference !== connection.connectedValue.connectedReference)
	#expect(graph.invocationOrder == ["reference", "reference", "value", "direct"])
}

// class·struct·actor 다단계 전달과 반복 접근의 transient 생성 확인
@Test
func providerDependencyConnectionCreatesTransientMultiStepValues() {
	// 전달 결과를 비교할 검증값
	let token = UUID()
	// 다단계 연결을 생성할 graph
	let graph = ProviderDependencyConnectionGraph(token: token)
	// 첫 번째 생성 경로
	let first = graph.connectedRoot
	// 두 번째 생성 경로
	let second = graph.connectedRoot
	// actor까지 전달된 첫 번째 struct 의존성
	let firstValue = first.connectedActor.connectedValue
	// actor까지 전달된 두 번째 struct 의존성
	let secondValue = second.connectedActor.connectedValue

	#expect(firstValue.connectedReference.token == token)
	#expect(secondValue.connectedReference.token == token)
	#expect(firstValue.connectedReference !== secondValue.connectedReference)
	#expect(first.connectedActor !== second.connectedActor)
	#expect(graph.invocationOrder == ["reference", "value", "actor", "root", "reference", "value", "actor", "root"])
}

// provider 선언 순서를 바꿔도 연결과 실행 결과가 유지되는지 확인
@Test
func providerDependencyConnectionIgnoresDeclarationOrder() {
	// 두 graph에 공통으로 전달할 검증값
	let token = UUID()
	// 의존 순서대로 선언한 graph
	let graph = ProviderDependencyConnectionGraph(token: token)
	// 의존 순서를 뒤집은 graph
	let reversedGraph = ReversedDependencyConnectionGraph(token: token)
	// 정상 선언 graph의 다단계 결과
	let root = graph.connectedRoot
	// 역순 선언 graph의 다단계 결과
	let reversedRoot = reversedGraph.connectedRoot
	// 정상 graph의 actor까지 전달된 값
	let value = root.connectedActor.connectedValue
	// 역순 graph의 actor까지 전달된 값
	let reversedValue = reversedRoot.connectedActor.connectedValue

	#expect(value.connectedReference.token == reversedValue.connectedReference.token)
	#expect(graph.invocationOrder == ["reference", "value", "actor", "root"])
	#expect(reversedGraph.invocationOrder == graph.invocationOrder)
}
