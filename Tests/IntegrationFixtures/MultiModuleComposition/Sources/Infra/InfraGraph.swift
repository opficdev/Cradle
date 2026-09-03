//
//  InfraGraph.swift
//  Infra
//
//  Created by opfic on 9/3/26.
//

import Cradle

// 외부 통신 없이 결정적인 응답을 제공하는 client
package struct UserAPIClient {
	// 원격 응답으로 사용할 사용자 이름
	private let name: String

	// 고정 응답 client 구성
	package init(name: String) {
		self.name = name
	}

	// 원격 사용자 이름 조회
	package func loadUserName() -> String {
		name
	}
}

// Infra 등록의 생성과 수명을 소유하는 source graph
@DependencyGraph
package final class InfraGraph {
	// 다른 fixture target의 명시적 graph 생성
	package init() {}

	// graph별로 한 번 생성할 client 등록
	@Provide
	private func makeUserAPIClient() -> UserAPIClient {
		UserAPIClient(name: "remote-user")
	}
}
