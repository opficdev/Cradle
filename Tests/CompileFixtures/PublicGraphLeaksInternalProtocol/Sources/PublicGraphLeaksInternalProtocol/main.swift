//
//  main.swift
//  PublicGraphLeaksInternalProtocol
//
//  Created by opfic on 8/30/26.
//

import Cradle

// 공개 접근자에서 노출할 수 없는 계약
protocol InternalRepositoryContract {}

// 비공개 계약을 준수하는 구현
struct HiddenRepository: InternalRepositoryContract {}

// 생성 접근자의 접근 수준을 컴파일러가 검사하는지 확인할 그래프
@DependencyGraph
public final class LeakingProtocolGraph {
	// 공개 생성 접근자에 비공개 계약을 노출하는 Factory
	@Provide(.transient)
	private func makeInternalRepositoryContract() -> any InternalRepositoryContract {
		HiddenRepository()
	}
}
