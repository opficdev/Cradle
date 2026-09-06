//
//  DependencyGraphLifetime.swift
//  Cradle
//
//  Created by opfic on 9/6/26.
//

// graph 인스턴스의 생성·보유 범위 정책
public enum DependencyGraphLifetime: Sendable {
	// 호출자가 직접 만드는 graph 인스턴스 범위
	case instance
	// 프로세스 동안 보유하는 정적 graph 범위
	case shared
}
