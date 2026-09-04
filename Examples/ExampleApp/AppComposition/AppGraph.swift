//
//  AppGraph.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import Cradle

// Data graph와 Presentation 생성을 연결하는 app graph
@DependencyGraph(sources: [DataGraph.self])
final class AppGraph {
	// Data graph의 Domain 계약으로 상품 조회 use case 생성
	@Provide
	private func makeLoadProductUseCase() -> LoadProductUseCase {
		LoadProductUseCase(repository: dataGraph.productRepository)
	}

	// graph 의존성과 외부 상품 식별자로 ViewModel 생성
	@Provide(.transient)
	private func makeProductDetailViewModel(
		useCase: LoadProductUseCase,
		@External productID: ProductID
	) -> ProductDetailViewModel {
		ProductDetailViewModel(useCase: useCase, productID: productID)
	}
}
