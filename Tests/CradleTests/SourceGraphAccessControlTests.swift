//
//  SourceGraphAccessControlTests.swift
//  CradleTests
//
//  Created by opfic on 9/2/26.
//

import CradleConsumerFixture
import Testing

// 별도 module에서 public source 조합 graph를 생성하고 접근할 수 있는지 확인
@Test
func anotherModuleCanUsePublicSourceGraphComposition() {
	let graph = PublicSourceFeatureGraph(publicSourceGraph: PublicSourceGraph())

	#expect(graph.publicSourceService.token == 64)
}

// protocol만 채택한 조합 graph가 외부 소비자 type으로도 동작하는지 확인
@Test
func publicSourceGraphCompositionConformsToProtocol() {
	let graph: any PublicSourceFeatureProviding = PublicSourceFeatureGraph(
		publicSourceGraph: PublicSourceGraph()
	)

	#expect(graph.publicSourceService.token == 64)
}

// 별도 module에서 source를 직접 읽는 shared 조합 graph를 생성할 수 있는지 확인
@Test
func anotherModuleCanUsePublicSharedSourceGraphComposition() {
	let graph = PublicSharedSourceFeatureGraph(publicSourceGraph: PublicSourceGraph())

	#expect(graph.publicSourceService.token == 64)
}

// source를 직접 읽는 shared 조합 graph가 외부 protocol로도 동작하는지 확인
@Test
func publicSharedSourceGraphCompositionConformsToProtocol() {
	let graph: any PublicSourceFeatureProviding = PublicSharedSourceFeatureGraph(
		publicSourceGraph: PublicSourceGraph()
	)

	#expect(graph.publicSourceService.token == 64)
}
