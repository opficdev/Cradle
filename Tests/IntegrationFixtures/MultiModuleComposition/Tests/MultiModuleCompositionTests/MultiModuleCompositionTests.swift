//
//  MultiModuleCompositionTests.swift
//  MultiModuleCompositionTests
//
//  Created by opfic on 9/3/26.
//

import AppComposition
import Domain
import Testing

// 여러 target의 graph가 Domain 결과까지 값을 전달하는지 확인
@Test
func multiModuleCompositionCombinesLayerGraphs() {
	// leaf graph부터 조립한 최상위 graph
	let graph = LayeredAppComposition.makeGraph()
	// Data Repository를 거쳐 생성한 Domain 결과
	let profile = graph.loadUserProfileUseCase.execute()

	#expect(profile == UserProfile(
		persistedName: "persisted-user",
		remoteName: "remote-user"
	))
}
