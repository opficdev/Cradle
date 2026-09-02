//
//  BodylessProviderGraphTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import Cradle
import Testing

// 본문 없는 Factory가 생성할 값
struct BodylessDependency: Equatable {
	let token = 42
}

// BodyMacro와 `DependencyGraphMacro` 통합 검증용 graph
@DependencyGraph
final class BodylessProviderGraph {
	@Provide
	private func provideBodylessDependency() -> BodylessDependency
}

// 본문 없는 Factory의 실제 graph 호출 확인
@Test
func bodylessProviderGraphBuildsDependency() {
	#expect(BodylessProviderGraph().bodylessDependency().token == 42)
}
