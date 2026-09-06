//
//  DependencyGraphLifetime.swift
//  Cradle
//
//  Created by opfic on 9/6/26.
//

// graph 인스턴스의 생성·보유 범위 정책
/**
 graph 인스턴스의 생성과 보유 범위를 정하는 정책입니다.

 `DependencyLifetime`이 Factory 결과의 수명을 정하는 것과 달리 graph 자체의 보유 범위를 정합니다.

 - Note: provider 결과의 평가 시점과 보유 방식은 `DependencyLifetime`로 따로 지정합니다.
 - SeeAlso: <doc:DependencyGraph>
 */
public enum DependencyGraphLifetime: Sendable {
	// 호출자가 직접 만드는 graph 인스턴스 범위
	/**
	 호출자가 직접 생성하고 보유하는 graph 인스턴스 범위입니다.

	 graph가 해제되면 graph가 보관하던 provider 결과의 참조도 놓습니다.

	 - Note: provider 결과의 보유 방식은 각 `@Provide`의 `DependencyLifetime`를 따릅니다.
	 - SeeAlso: <doc:DependencyGraph>
	 */
	case instance
	// 프로세스 동안 보유하는 정적 graph 범위
	/**
	 프로세스 동안 보유하는 `static let shared` graph 범위입니다.

	 `actor`와 `@MainActor` graph는 기존 격리를 유지합니다. 비격리 `final class`는 직접 `Sendable`
	 준수를 선언해야 합니다.

	 - Warning: 이 graph는 프로세스 동안 보유되므로 해제 시점을 검증하는 대상이 아닙니다.
	 - SeeAlso: <doc:DependencyGraph>
	 */
	case shared
}
