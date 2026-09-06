//
//  DependencyLifetime.swift
//  Cradle
//
//  Created by opfic on 9/2/26.
//

// graph가 Factory 결과를 소유하는 수명 정책
/// Factory 결과를 graph가 평가하고 보유하는 방식을 정하는 정책입니다.
///
/// `DependencyGraphLifetime`의 graph 인스턴스 보유 범위와 구분됩니다. 각 정책의 사용 조건은 <doc:DependencyGraph>에서 설명합니다.
public enum DependencyLifetime: Sendable {
	// graph 생성 중 한 번 만들고 해당 graph에서 재사용
	/// graph를 생성할 때 Factory 결과를 한 번 만들고 해당 graph가 보관하는 정책입니다.
	///
	/// provider 수명과 graph 수명의 차이는 <doc:DependencyGraph>에서 설명합니다.
	case shared
	// 생성 프로퍼티를 처음 읽을 때 graph별로 한 번 생성
	/// 생성 프로퍼티를 처음 읽을 때 Factory 결과를 graph별로 한 번 만드는 정책입니다.
	///
	/// provider 수명별 평가 시점은 <doc:DependencyGraph>에서 설명합니다.
	case lazy
	// 생성 프로퍼티를 읽을 때마다 Factory를 호출
	/// 생성 프로퍼티를 읽거나 외부 입력 생성 메서드를 호출할 때마다 Factory를 평가하는 정책입니다.
	///
	/// 외부 입력과 provider 수명 사용 조건은 <doc:DependencyGraph>에서 설명합니다.
	case transient
}
