//
//  main.swift
//  CircularDependency
//
//  Created by opfic on 8/30/26.
//

import Cradle

// 자기 순환과 다중 순환의 첫 반환 타입
struct FirstService {}

// 다중 순환의 두 번째 반환 타입
struct SecondService {}

// 다중 순환의 세 번째 반환 타입
struct ThirdService {}

// 자기 자신을 요구하는 등록의 컴파일 오류 확인
@DependencyGraph
final class SelfCycleGraph {
	// 자기 순환을 닫는 원본 매개변수
	@Provide
	private func makeFirstService(firstService: FirstService) -> FirstService { FirstService() }
}

// 세 등록 사이의 순환과 모든 등록 위치 확인
@DependencyGraph
final class MultiCycleGraph {
	// 두 번째 등록을 요구하는 첫 Factory
	@Provide
	private func makeFirstService(secondService: SecondService) -> FirstService { FirstService() }

	// 세 번째 등록을 요구하는 두 번째 Factory
	@Provide
	private func makeSecondService(thirdService: ThirdService) -> SecondService { SecondService() }

	// 주석 뒤의 지역 이름에서 순환을 닫는 Factory
	@Provide
	private func `makeThirdService`(
		_ /* closing */ `firstService`: FirstService
	) -> ThirdService { ThirdService() }
}
