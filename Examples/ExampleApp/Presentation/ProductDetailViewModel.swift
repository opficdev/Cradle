//
//  ProductDetailViewModel.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import Combine

// 상품 상세 화면의 상태와 Domain 실행을 연결하는 ViewModel
@MainActor
final class ProductDetailViewModel: ObservableObject {
	// 화면에 표시할 상품 상태
	@Published private(set) var product: Product?

	// 상품 조회를 수행할 Domain use case
	private let useCase: LoadProductUseCase
	// 호출 시점에 정해진 상품 식별자
	private let productID: ProductID

	// Domain use case와 외부 상품 식별자 주입
	init(useCase: LoadProductUseCase, productID: ProductID) {
		self.useCase = useCase
		self.productID = productID
	}

	// 상품 상세를 조회해 화면 상태 갱신
	func load() {
		product = useCase.execute(id: productID)
	}
}
