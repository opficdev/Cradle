//
//  main.swift
//  SourceGraphInvalidUsage
//
//  Created by opfic on 9/2/26.
//

import Cradle

// 존재하지 않는 source 접근자 오류 확인용 반환 타입
struct SourceGraphMissingFeature {}

// 비공개 source member 오류 확인용 반환 타입
struct SourceGraphPrivateFeature {}

// source 반환 타입 불일치 오류 확인용 기대 타입
struct SourceGraphExpectedFeature {}

// source가 실제로 반환할 타입
struct SourceGraphActualFeature {}

// public 접근자를 제공하는 source graph
@DependencyGraph
final class SourceGraphGetterSource {
	@Provide(.transient)
	private func makeSourceGraphActualFeature() -> SourceGraphActualFeature {
		SourceGraphActualFeature()
	}
}

// 존재하지 않는 접근자를 읽는 조합 graph
@DependencyGraph(sources: [SourceGraphGetterSource.self])
final class SourceGraphMissingGetterGraph {
	@Provide(.transient)
	private func makeSourceGraphMissingFeature() -> SourceGraphMissingFeature {
		sourceGraphGetterSource.missingFeature
	}
}

// 비공개 instance member를 가진 source graph
@DependencyGraph
final class SourceGraphPrivateSource {
	private let privateFeature = SourceGraphPrivateFeature()
}

// 비공개 source member를 읽는 조합 graph
@DependencyGraph(sources: [SourceGraphPrivateSource.self])
final class SourceGraphPrivateGetterGraph {
	@Provide(.transient)
	private func makeSourceGraphPrivateFeature() -> SourceGraphPrivateFeature {
		sourceGraphPrivateSource.privateFeature
	}
}

// source 반환 타입을 기대 타입으로 바꾸지 않는지 확인할 조합 graph
@DependencyGraph(sources: [SourceGraphGetterSource.self])
final class SourceGraphTypeMismatchGraph {
	@Provide(.transient)
	private func makeSourceGraphExpectedFeature() -> SourceGraphExpectedFeature {
		sourceGraphGetterSource.sourceGraphActualFeature
	}
}
