//
//  DependencyOverride.swift
//  Cradle
//
//  Created by opfic on 9/3/26.
//

// graph 생성 전에 기본 Factory 또는 교체 Factory를 선택하는 상태
public enum DependencyOverride<Factory> {
	// graph 선언에 작성한 기본 Factory 선택
	case original
	// graph 인스턴스에만 적용할 타입 지정 교체 Factory 선택
	case factory(Factory)
}

// Sendable Factory 상태의 actor 경계 전달
extension DependencyOverride: Sendable where Factory: Sendable {}
