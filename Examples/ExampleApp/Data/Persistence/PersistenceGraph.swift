//
//  PersistenceGraph.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import Cradle

// 상품 저장소 등록을 소유하는 override 가능 source graph
@DependencyGraph(overrides: true)
final class PersistenceGraph {
	// 기본 구성에서 비어 있는 메모리 저장소 생성
	@Provide
	private func makeProductStore() -> ProductStore {
		ProductStore(storedProduct: nil)
	}
}
