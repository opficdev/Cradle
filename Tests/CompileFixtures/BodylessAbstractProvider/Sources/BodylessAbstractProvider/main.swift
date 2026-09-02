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
	@Provide(.transient)
	private func makeRepository() -> any Repository
}

// 본문 없는 Factory가 접근할 수 없는 initializer를 가진 상위 클래스
class RepositorySuperclass {
	private init() {}
}

// 접근할 수 없는 상위 클래스 initializer의 오류를 확인할 graph
@DependencyGraph
final class BodylessSuperclassGraph {
	@Provide(.transient)
	private func makeRepositorySuperclass() -> RepositorySuperclass
}
