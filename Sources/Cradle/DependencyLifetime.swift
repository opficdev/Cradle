//
//  DependencyLifetime.swift
//  Cradle
//
//  Created by opfic on 9/2/26.
//

// graph가 Factory 결과를 소유하는 수명 정책
/**
 Factory 결과를 graph가 평가하고 보유하는 방식을 정하는 정책입니다.

 `DependencyGraphLifetime`의 graph 인스턴스 보유 범위와 구분됩니다.

 - Note: 이 정책은 graph 자체의 생성 방식이나 보유 기간을 변경하지 않습니다.
 */
public enum DependencyLifetime: Sendable {
	// graph 생성 중 한 번 만들고 해당 graph에서 재사용
	/**
	 graph를 생성할 때 Factory 결과를 한 번 만들고 해당 graph가 보관하는 정책입니다.

	 같은 graph 인스턴스의 생성 프로퍼티를 여러 번 읽어도 같은 결과를 반환합니다.

	 - Note: 전역 singleton이 아니라 graph 인스턴스별로 결과를 보관합니다.
	 */
	case shared
	// 생성 프로퍼티를 처음 읽을 때 graph별로 한 번 생성
	/**
	 생성 프로퍼티를 처음 읽을 때 Factory 결과를 graph별로 한 번 만드는 정책입니다.

	 Factory는 첫 접근 시점의 graph 상태를 읽고, 생성한 결과는 해당 graph가 보관합니다.

	 - Warning: `Sendable`을 준수하는 비격리 class의 `.shared` graph에는 사용할 수 없습니다.
	 */
	case lazy
	// 생성 프로퍼티를 읽을 때마다 Factory를 호출
	/**
	 생성 프로퍼티를 읽거나 외부 입력 생성 메서드를 호출할 때마다 Factory를 평가하는 정책입니다.

	 graph는 생성한 결과를 보관하지 않습니다.

	 - Important: 호출 시점 입력이 필요하면 Factory 매개변수에 `@External`을 함께 사용합니다.
	 */
	case transient
}
