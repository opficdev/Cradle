//
//  LoadProductUseCase.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

// 상품 조회 계약에 실행을 위임하는 Domain use case
struct LoadProductUseCase {
	// 상품 조회를 수행할 Domain 계약
	private let repository: any ProductRepository

	// Domain 계약 주입
	init(repository: any ProductRepository) {
		self.repository = repository
	}

	// 식별자에 해당하는 상품 상세 조회
	func execute(id: ProductID) -> Product {
		repository.product(for: id)
	}
}
