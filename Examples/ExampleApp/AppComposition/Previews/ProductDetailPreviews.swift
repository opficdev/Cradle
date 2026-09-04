//
//  ProductDetailPreviews.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import Cradle
import SwiftUI

// 저장값이 없을 때 Infra 결과를 표시하는 Preview 구성
@MainActor
private func infraProductDetailPreview() -> some View {
	// 저장값이 없는 기본 Persistence graph
	let persistenceGraph = PersistenceGraph()
	// 결정적인 상품을 제공할 기본 Infra graph
	let infraGraph = InfraGraph()
	// Preview가 독립적으로 소유할 Data graph
	let dataGraph = DataGraph(
		infraGraph: infraGraph,
		persistenceGraph: persistenceGraph
	)
	// Preview가 독립적으로 소유할 앱 graph
	let graph = AppGraph(dataGraph: dataGraph)
	// 외부 상품 식별자로 생성한 Preview 전용 ViewModel
	let viewModel = graph.productDetailViewModel(
		productID: ProductID(rawValue: "remote-product")
	)

	return ProductDetailView(viewModel: viewModel)
}

// Persistence 등록을 교체한 Preview 구성
@MainActor
private func persistenceProductDetailPreview() -> some View {
	// 등록 소유 graph에 직접 적용한 저장 상품 교체
	let persistenceGraph = PersistenceGraph.override(
		productStore: .replace {
			ProductStore(
				storedProduct: StoredProduct(
					id: ProductID(rawValue: "stored-product"),
					name: "저장 상품",
					summary: "Persistence 계층에서 제공한 상품"
				)
			)
		}
	).build()
	// 교체를 전파하지 않는 독립 Infra graph
	let infraGraph = InfraGraph()
	// 교체한 Persistence graph를 직접 받는 Data graph
	let dataGraph = DataGraph(
		infraGraph: infraGraph,
		persistenceGraph: persistenceGraph
	)
	// Preview가 독립적으로 소유할 앱 graph
	let graph = AppGraph(dataGraph: dataGraph)
	// 저장 상품 식별자로 생성한 Preview 전용 ViewModel
	let viewModel = graph.productDetailViewModel(
		productID: ProductID(rawValue: "stored-product")
	)

	return ProductDetailView(viewModel: viewModel)
}

#Preview("Infra 대체 조회") {
	infraProductDetailPreview()
}

#Preview("Persistence 교체") {
	persistenceProductDetailPreview()
}
