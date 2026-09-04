//
//  Product.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

// 상품을 구분하는 Domain 식별자
struct ProductID: Hashable, Sendable {
	// 외부 입력으로 전달할 원시 식별값
	let rawValue: String
}

// 상품 상세 화면이 표시할 Domain entity
struct Product: Equatable, Sendable {
	// 조회한 상품의 식별자
	let id: ProductID
	// 화면에 표시할 상품 이름
	let name: String
	// 화면에 표시할 상품 설명
	let summary: String
}
