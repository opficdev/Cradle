//
//  ProductStore.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

// Persistence 계층이 보관할 상품 데이터
struct StoredProduct {
	// 저장한 상품 식별자
	let id: ProductID
	// 저장한 상품 이름
	let name: String
	// 저장한 상품 설명
	let summary: String
}

// 단일 상품의 메모리 저장 상태를 제공하는 저장소
struct ProductStore {
	// 메모리에 보관한 상품 데이터
	private let storedProduct: StoredProduct?

	// 상품이 있거나 없는 저장 상태 구성
	init(storedProduct: StoredProduct?) {
		self.storedProduct = storedProduct
	}

	// 식별자가 일치하는 저장 상품 조회
	func product(for id: ProductID) -> StoredProduct? {
		guard storedProduct?.id == id else {
			return nil
		}
		return storedProduct
	}
}
