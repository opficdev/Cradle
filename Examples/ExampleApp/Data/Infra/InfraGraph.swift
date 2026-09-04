//
//  InfraGraph.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import Cradle

// 상품 client 등록을 소유하는 source graph
@DependencyGraph
final class InfraGraph {
	// 결정적인 상품 응답을 제공할 client 생성
	@Provide
	private func makeProductClient() -> ProductClient {
		ProductClient()
	}
}
