//
//  DependencyLifetime.swift
//  Cradle
//
//  Created by opfic on 9/2/26.
//

// graph가 Factory 결과를 소유하는 수명 정책
public enum DependencyLifetime: Sendable {
	// graph 생성 중 한 번 만들고 해당 graph에서 재사용
	case shared
}
