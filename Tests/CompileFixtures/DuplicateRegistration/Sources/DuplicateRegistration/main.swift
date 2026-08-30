//
//  main.swift
//  DuplicateRegistration
//
//  Created by opfic on 8/30/26.
//

import Cradle

// 중복 등록할 프로토콜 반환 계약
protocol Repository {}

// 첫 번째 Factory의 반환 구현
struct FirstRepository: Repository {}

// 두 번째 Factory의 반환 구현
struct SecondRepository: Repository {}

// 세 번째 Factory의 반환 구현
struct ThirdRepository: Repository {}

// 하나의 접근자에 세 Factory를 등록한 컴파일 실패 그래프
@DependencyGraph
final class DuplicateRegistrationGraph {
	// 여러 줄 반환 선언에서 주 오류를 표시할 대표 등록
	@Provide
	private func makeFirst() ->
		/* result */ any Repository {
		FirstRepository()
	}

	// 같은 접근자 이름을 만드는 두 번째 등록
	@Provide
	private func makeSecond() -> any Repository {
		SecondRepository()
	}

	// 백틱 Factory 이름의 보조 설명을 확인할 세 번째 등록
	@Provide
	private func `makeThird`() -> any Repository {
		ThirdRepository()
	}
}
