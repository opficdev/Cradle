//
//  ProductClient.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

// Infra 계층이 제공할 상품 응답
struct ProductResponse {
	// 요청한 상품 식별자
	let id: ProductID
	// 결정적인 상품 이름
	let name: String
	// 결정적인 상품 설명
	let summary: String
}

// 실제 통신 없이 결정적인 상품 응답을 제공하는 client
struct ProductClient {
	// 식별자에 대응하는 상품 응답 생성
	func product(for id: ProductID) -> ProductResponse {
		ProductResponse(
			id: id,
			name: "기본 상품",
			summary: "Infra 계층에서 제공한 상품 \(id.rawValue)"
		)
	}
}
