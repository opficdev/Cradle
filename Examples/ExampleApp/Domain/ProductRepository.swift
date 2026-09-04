//
//  ProductRepository.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

// Data 계층이 구현할 상품 조회 계약
protocol ProductRepository {
	// 식별자에 해당하는 상품 조회
	func product(for id: ProductID) -> Product
}
