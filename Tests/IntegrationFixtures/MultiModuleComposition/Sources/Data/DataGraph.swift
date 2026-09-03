//
//  DataGraph.swift
//  Data
//
//  Created by opfic on 9/3/26.
//

import Cradle
import Domain
import Infra
import Persistence

// Persistence와 Infra 구현을 Domain 계약으로 감추는 Repository
private struct LiveUserRepository: UserRepository {
	// 저장소에서 가져온 사용자 값
	let persistedUser: PersistedUser
	// 원격 사용자 조회 client
	let userAPIClient: UserAPIClient

	// Persistence와 Infra 결과를 Domain 값으로 변환
	func loadUserProfile() -> UserProfile {
		UserProfile(
			persistedName: persistedUser.name,
			remoteName: userAPIClient.loadUserName()
		)
	}
}

// PersistenceGraph와 InfraGraph를 조합하는 Data source graph
@DependencyGraph(sources: [
	PersistenceGraph.self,
	InfraGraph.self
])
package final class DataGraph {
	// Data 구현을 숨긴 Domain Repository 등록
	@Provide
	private func makeUserRepository() -> any UserRepository {
		LiveUserRepository(
			persistedUser: persistenceGraph.persistedUser,
			userAPIClient: infraGraph.userAPIClient
		)
	}
}
