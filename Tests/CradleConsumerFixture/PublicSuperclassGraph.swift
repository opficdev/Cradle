//
//  PublicSuperclassGraph.swift
//  CradleConsumerFixture
//
//  Created by opfic on 9/2/26.
//

import Cradle

// 외부 소비자에게 공개할 상위 클래스 계약
public class PublicRepositorySuperclass {
	// 외부에서 확인할 구현 값
	public let token: Int

	// 하위 구현이 값을 전달할 initializer
	public init(token: Int) {
		self.token = token
	}
}

// 외부에 공개하지 않을 하위 구현
final class InternalRepositorySubclass: PublicRepositorySuperclass {
	// 상위 클래스 계약에 전달할 구현 값
	init() {
		super.init(token: 84)
	}
}

// 상위 클래스 타입만 외부에 노출하는 graph
@DependencyGraph
public final class PublicSuperclassGraph {
	// 외부 graph 생성 허용 initializer
	public init() {}

	// 비공개 하위 구현을 공개 상위 클래스 타입으로 반환
	@Provide
	private func makePublicRepositorySuperclass() -> PublicRepositorySuperclass {
		InternalRepositorySubclass()
	}
}
