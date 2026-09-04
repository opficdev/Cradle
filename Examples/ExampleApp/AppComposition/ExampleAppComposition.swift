//
//  ExampleAppComposition.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

// leaf source graph부터 앱 graph까지 조립하고 소유하는 Composition Root
final class ExampleAppComposition {
	// 조립한 계층 graph를 소유할 앱 graph
	private let graph: AppGraph

	// Persistence부터 앱 graph까지 명시적인 생성 순서로 조립
	init() {
		let persistenceGraph = PersistenceGraph()
		let infraGraph = InfraGraph()
		let dataGraph = DataGraph(
			infraGraph: infraGraph,
			persistenceGraph: persistenceGraph
		)
		graph = AppGraph(dataGraph: dataGraph)
	}

	// 호출 시점 상품 식별자로 새로운 ViewModel 생성
	func makeProductDetailViewModel(productID: ProductID) -> ProductDetailViewModel {
		graph.productDetailViewModel(productID: productID)
	}
}
