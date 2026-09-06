//
//  DependencyGraphLifetime.swift
//  Cradle
//
//  Created by opfic on 9/6/26.
//

// graph 인스턴스의 생성·보유 범위 정책
/// graph 인스턴스의 생성과 보유 범위를 정하는 정책입니다.
///
/// `DependencyLifetime`가 Factory 결과의 수명을 정하는 것과 달리 graph 자체의 보유 범위를 정합니다. 자세한 사용 조건은 <doc:DependencyGraph>에서 설명합니다.
public enum DependencyGraphLifetime: Sendable {
	// 호출자가 직접 만드는 graph 인스턴스 범위
	/// 호출자가 직접 생성하고 보유하는 graph 인스턴스 범위입니다.
	///
	/// graph 수명과 provider 결과 수명의 차이는 <doc:DependencyGraph>에서 설명합니다.
	case instance
	// 프로세스 동안 보유하는 정적 graph 범위
	/// 프로세스 동안 보유하는 `static let shared` graph 범위입니다.
	///
	/// graph 수명과 동시성 조건은 <doc:DependencyGraph>에서 설명합니다.
	case shared
}
