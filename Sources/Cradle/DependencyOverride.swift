//
//  DependencyOverride.swift
//  Cradle
//
//  Created by opfic on 9/3/26.
//

// graph 생성 전에 기본 Factory 또는 교체 Factory를 선택하는 상태
/// graph를 만들기 전에 원본 또는 교체 Factory를 선택하는 값입니다.
///
/// 선택은 `Graph.override(...).build()`로 만드는 graph 인스턴스에만 적용합니다. `Factory`가 `Sendable`이면 이 값도 `Sendable`을 준수합니다. 자세한 교체 조건은 <doc:DependencyGraph>에서 설명합니다.
public enum DependencyOverride<Factory> {
	// graph 선언에 작성한 기본 Factory 선택
	/// graph 선언에 작성한 원본 Factory를 선택합니다.
	///
	/// 교체 Factory의 적용 범위는 <doc:DependencyGraph>에서 설명합니다.
	case original
	// graph 인스턴스에만 적용할 타입 지정 교체 Factory 선택
	/// 생성할 graph 인스턴스에 적용할 교체 Factory를 선택합니다.
	///
	/// 이 선택은 Factory를 실행하거나 `Graph.shared`를 변경하지 않습니다. 실행 시점과 제약은 <doc:DependencyGraph>에서 설명합니다.
	case replace(Factory)
}

// Sendable Factory 상태의 actor 경계 전달
extension DependencyOverride: Sendable where Factory: Sendable {}
