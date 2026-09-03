//
//  TypedOverrideClassTests.swift
//  CradleTests
//
//  Created by opfic on 9/3/26.
//

import Cradle
import Testing

// override Factory 실행 횟수 확인용 참조 값
final class TypedOverrideSharedService {
	// 생성 순서 확인 값
	let value: Int

	init(value: Int) {
		self.value = value
	}
}

// shared 의존성을 받는 transient 결과
struct TypedOverrideTransientService {
	// 주입된 shared 결과
	let shared: TypedOverrideSharedService
}

// 교체 Factory 실행 횟수 확인용 참조 값
final class TypedOverrideFactoryProbe {
	// shared 교체 Factory 호출 횟수
	var sharedCount = 0
	// transient 교체 Factory 호출 횟수
	var transientCount = 0
}

// 조합 graph에 전달할 source graph 값
@DependencyGraph
final class TypedOverrideSourceGraph {
	@Provide
	private func makeTypedOverrideSourceValue() -> TypedOverrideSourceValue {
		TypedOverrideSourceValue(value: 5)
	}
}

// source graph 결과 값
struct TypedOverrideSourceValue {
	// source graph 전달값
	let value: Int
}

// source graph와 직접 등록 override를 함께 확인할 조합 graph
@DependencyGraph(sources: [TypedOverrideSourceGraph.self], overrides: true)
final class TypedOverrideFeatureGraph {
	@Provide(.transient)
	private func makeTypedOverrideFeatureValue() -> TypedOverrideFeatureValue {
		TypedOverrideFeatureValue(value: typedOverrideSourceGraph.typedOverrideSourceValue.value)
	}
}

// 조합 graph가 노출할 결과 값
struct TypedOverrideFeatureValue {
	// source 또는 override에서 받은 값
	let value: Int
}

// actor graph 교체 결과 확인용 Sendable 값
struct TypedOverrideActorValue: Sendable {
	// 교체 결과 검증값
	let value: Int
}

// shared 수명과 identity 확인용 actor 의존성
actor TypedOverrideActorSharedService {
	// 교체 결과 검증값
	let value: Int

	init(value: Int) {
		self.value = value
	}
}

// actor graph가 매번 만들 transient 결과
struct TypedOverrideActorTransientValue: Sendable {
	// actor graph가 보관한 shared 의존성
	let shared: TypedOverrideActorSharedService
}

// Sendable 교체 Factory를 받는 actor graph
@DependencyGraph(overrides: true)
actor TypedOverrideActorGraph {
	@Provide
	private func makeTypedOverrideActorValue() -> TypedOverrideActorValue {
		TypedOverrideActorValue(value: 13)
	}

	@Provide
	private func makeTypedOverrideActorSharedService() -> TypedOverrideActorSharedService {
		TypedOverrideActorSharedService(value: 34)
	}

	@Provide(.transient)
	private func makeTypedOverrideActorTransientValue(
		shared: TypedOverrideActorSharedService
	) -> TypedOverrideActorTransientValue {
		TypedOverrideActorTransientValue(shared: shared)
	}
}

// source 참조 shared Factory 재작성을 확인할 조합 graph
@DependencyGraph(sources: [TypedOverrideSourceGraph.self], overrides: true)
final class TypedOverrideSharedFeatureGraph {
	@Provide
	private func makeTypedOverrideSharedFeatureValue() -> TypedOverrideFeatureValue {
		TypedOverrideFeatureValue(value: typedOverrideSourceGraph.typedOverrideSourceValue.value)
	}
}

// class graph override 생성 경로 확인용 graph
@DependencyGraph(overrides: true)
final class TypedOverrideClassGraph {
	// 기본 shared 결과 생성
	@Provide
	private func makeTypedOverrideSharedService() -> TypedOverrideSharedService {
		return TypedOverrideSharedService(value: 1)
	}

	// shared 결과를 받는 transient 생성
	@Provide(.transient)
	private func makeTypedOverrideTransientService(
		shared: TypedOverrideSharedService
	) -> TypedOverrideTransientService {
		TypedOverrideTransientService(shared: shared)
	}
}

// 교체 shared Factory와 원본 transient 연결 확인
@Test
func typedOverrideClassGraphUsesReplacementAndOriginalDependencies() {
	let graph = TypedOverrideClassGraph.override(
		typedOverrideSharedService: .factory {
			TypedOverrideSharedService(value: 2)
		}
	).build()
	let first = graph.typedOverrideTransientService
	let second = graph.typedOverrideTransientService

	#expect(first.shared === second.shared)
	#expect(first.shared.value == 2)
}

// 생략한 등록의 원본 경로와 builder 생성 지연 확인
@Test
func typedOverrideClassGraphDefersFactoryEvaluationUntilBuild() {
	let probe = TypedOverrideFactoryProbe()
	let builder = TypedOverrideClassGraph.override(
		typedOverrideSharedService: .factory {
			probe.sharedCount += 1
			return TypedOverrideSharedService(value: 3)
		},
		typedOverrideTransientService: .factory { shared in
			probe.transientCount += 1
			return TypedOverrideTransientService(shared: shared)
		}
	)

	#expect(probe.sharedCount == 0)
	#expect(probe.transientCount == 0)
	let first = builder.build()
	let second = builder.build()

	#expect(probe.sharedCount == 2)
	#expect(first.typedOverrideSharedService !== second.typedOverrideSharedService)
	_ = first.typedOverrideTransientService
	_ = first.typedOverrideTransientService
	#expect(probe.transientCount == 2)
	#expect(TypedOverrideClassGraph().typedOverrideSharedService.value == 1)
}

// source graph를 먼저 전달한 뒤 조합 graph를 생성하는지 확인
@Test
func typedOverrideSourceGraphBuildsWithSourceArguments() {
	let graph = TypedOverrideFeatureGraph.override(
		typedOverrideFeatureValue: .factory {
			TypedOverrideFeatureValue(value: 8)
		}
	).build(typedOverrideSourceGraph: TypedOverrideSourceGraph())

	#expect(graph.typedOverrideFeatureValue.value == 8)
}

// shared Factory가 source graph 참조를 builder 초기화 경로로 전달받는지 확인
@Test
func typedOverrideSourceGraphBuildsSharedFactoryFromSource() {
	let graph = TypedOverrideSharedFeatureGraph.override()
		.build(typedOverrideSourceGraph: TypedOverrideSourceGraph())

	#expect(graph.typedOverrideFeatureValue.value == 5)
}

// actor graph가 Sendable 교체 Factory를 보관하고 actor 격리 접근자로 반환하는지 확인
@Test
func typedOverrideActorGraphBuildsWithSendableFactory() async {
	let graph = TypedOverrideActorGraph.override(
		typedOverrideActorValue: .factory {
			TypedOverrideActorValue(value: 21)
		},
		typedOverrideActorSharedService: .factory {
			TypedOverrideActorSharedService(value: 55)
		}
	).build()
	let first = await graph.typedOverrideActorTransientValue
	let second = await graph.typedOverrideActorTransientValue

	#expect(await graph.typedOverrideActorValue.value == 21)
	#expect(first.shared === second.shared)
	#expect(first.shared.value == 55)
}
