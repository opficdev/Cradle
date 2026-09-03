//
//  DependencyOverride+Mock.swift
//  CradleTesting
//
//  Created by opfic on 9/3/26.
//

import Cradle

/// 테스트 대역 Factory를 graph 인스턴스별 교체 상태로 감쌉니다.
public extension DependencyOverride {
	/// Factory 실행을 지연한 `.replace` 상태를 만듭니다.
	static func mock(_ factory: Factory) -> Self {
		.replace(factory)
	}
}
