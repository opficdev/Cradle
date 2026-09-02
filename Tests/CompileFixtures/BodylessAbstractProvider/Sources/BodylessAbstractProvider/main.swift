//
//  main.swift
//  BodylessAbstractProvider
//
//  Created by opfic on 9/2/26.
//

import Cradle

// 본문 없는 Factory가 직접 생성할 수 없는 추상 계약
protocol Repository {}

// 추상 반환 타입의 본문 없는 Factory를 포함한 graph
@DependencyGraph
final class BodylessAbstractGraph {
	@Provide
	private func makeRepository() -> any Repository
}
