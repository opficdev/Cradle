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

// 레이블이 있는 initializer를 받을 첫 번째 의존성
struct BodylessRepository {
	let token = 7
}

// 레이블이 없는 initializer를 받을 두 번째 의존성
struct BodylessLogger {
	let token = 9
}

// 외부 레이블과 순서를 보존해 생성할 값
struct BodylessFeature {
	let repository: BodylessRepository
	let logger: BodylessLogger

	init(client repository: BodylessRepository, _ logger: BodylessLogger) {
		self.repository = repository
		self.logger = logger
	}
}

// BodyMacro와 `DependencyGraphMacro` 통합 검증용 graph
@DependencyGraph
final class BodylessProviderGraph {
	@Provide(.transient)
	private func provideBodylessDependency() -> BodylessDependency
}

// 레이블이 있는 concrete initializer를 호출할 graph
@DependencyGraph
final class BodylessLabeledProviderGraph {
	@Provide(.transient)
	private func provideBodylessFeature(
		client repository: BodylessRepository,
		_ logger: BodylessLogger
	) -> BodylessFeature

	@Provide(.transient)
	private func provideBodylessRepository() -> BodylessRepository

	@Provide(.transient)
	private func provideBodylessLogger() -> BodylessLogger
}

// 본문 없는 Factory의 실제 graph 호출 확인
@Test
func bodylessProviderGraphBuildsDependency() {
	#expect(BodylessProviderGraph().bodylessDependency.token == 42)
}

// 본문 없는 Factory가 initializer의 외부 레이블과 인자 순서를 보존하는지 확인
@Test
func bodylessProviderGraphBuildsLabeledDependency() {
	let feature = BodylessLabeledProviderGraph().bodylessFeature
	#expect(feature.repository.token == 7)
	#expect(feature.logger.token == 9)
}
