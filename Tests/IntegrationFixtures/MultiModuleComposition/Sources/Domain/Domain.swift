//
//  Domain.swift
//  Domain
//
//  Created by opfic on 9/3/26.
//

// Repository가 계층 입력으로 구성할 결과
package struct UserProfile: Equatable {
	// Persistence 계층에서 가져온 값
	package let persistedName: String
	// Infra 계층에서 가져온 값
	package let remoteName: String

	// 계층별 결과 값 구성
	package init(persistedName: String, remoteName: String) {
		self.persistedName = persistedName
		self.remoteName = remoteName
	}
}

// Data 계층이 구현할 사용자 조회 계약
package protocol UserRepository {
	// Persistence와 Infra 결과를 조합한 사용자 조회
	func loadUserProfile() -> UserProfile
}

// AppComposition이 Repository를 주입할 Domain 동작
package struct LoadUserProfileUseCase {
	// 사용자 조회를 위임할 Domain 계약
	private let repository: any UserRepository

	// Domain 계약 주입
	package init(repository: any UserRepository) {
		self.repository = repository
	}

	// Repository를 통한 사용자 조회
	package func execute() -> UserProfile {
		repository.loadUserProfile()
	}
}
