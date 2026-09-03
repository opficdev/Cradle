//
//  PersistenceGraph.swift
//  Persistence
//
//  Created by opfic on 9/3/26.
//

import Cradle

// PersistenceGraph가 graph별로 보관할 사용자 값
package struct PersistedUser {
	// 저장소에서 읽은 사용자 이름
	package let name: String

	// 저장 사용자 값 구성
	package init(name: String) {
		self.name = name
	}
}

// Persistence 등록의 생성과 수명을 소유하는 source graph
@DependencyGraph
package final class PersistenceGraph {
	// 다른 fixture target의 명시적 graph 생성
	package init() {}

	// graph별로 한 번 생성할 저장 사용자 등록
	@Provide
	private func makePersistedUser() -> PersistedUser {
		PersistedUser(name: "persisted-user")
	}
}
