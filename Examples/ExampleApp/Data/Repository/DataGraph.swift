//
//  DataGraph.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import Cradle

// Persistence와 Infra를 Domain 상품 계약으로 감추는 Repository
private struct DefaultProductRepository: ProductRepository {
	// 저장된 상품을 먼저 조회할 저장소
	let store: ProductStore
	// 저장된 상품이 없을 때 사용할 client
	let client: ProductClient

	// 저장 상품을 우선 사용하고 없으면 Infra 응답을 Domain entity로 변환
	func product(for id: ProductID) -> Product {
		if let product = store.product(for: id) {
			return Product(
				id: product.id,
				name: product.name,
				summary: product.summary
			)
		}

		let response = client.product(for: id)
		return Product(
			id: response.id,
			name: response.name,
			summary: response.summary
		)
	}
}

// Persistence와 Infra source graph를 Domain 계약으로 조합하는 Data graph
@DependencyGraph(sources: [
	PersistenceGraph.self,
	InfraGraph.self
])
final class DataGraph {
	// 구체 구현을 숨긴 Domain 상품 조회 계약 생성
	@Provide
	private func makeProductRepository() -> any ProductRepository {
		DefaultProductRepository(
			store: persistenceGraph.productStore,
			client: infraGraph.productClient
		)
	}
}
