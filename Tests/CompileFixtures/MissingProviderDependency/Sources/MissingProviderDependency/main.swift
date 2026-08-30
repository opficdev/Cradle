//
//  main.swift
//  MissingProviderDependency
//
//  Created by opfic on 8/30/26.
//

import Cradle

// 누락 연결을 가진 service
struct MissingService {}

// 등록되지 않은 의존성
struct MissingRepository {}

// 일반 메서드로 누락 등록을 대신할 수 없는지 검증하는 graph
@DependencyGraph
final class MissingProviderDependencyGraph {
	// 이름이 같아도 등록 생성 접근자로 인정하지 않는 일반 메서드
	func missingRepository() -> MissingRepository {
		MissingRepository()
	}

	// 등록되지 않은 지역 이름을 요구하는 provider
	@Provide
	private func makeMissingService(
		repository missingRepository: MissingRepository
	) -> MissingService {
		MissingService()
	}
}
