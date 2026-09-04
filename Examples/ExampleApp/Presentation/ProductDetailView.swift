//
//  ProductDetailView.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import SwiftUI

// 주입받은 ViewModel의 수명을 소유하는 상품 상세 View
@MainActor
struct ProductDetailView: View {
	// 화면 수명 동안 보관할 ViewModel
	@StateObject private var viewModel: ProductDetailViewModel

	// Optional이 아닌 ViewModel 주입과 StateObject 초기화
	init(viewModel: ProductDetailViewModel) {
		_viewModel = StateObject(wrappedValue: viewModel)
	}

	// 상품 조회 상태에 따른 화면 구성
	var body: some View {
		NavigationStack {
			Group {
				// ViewModel이 제공한 상품 상세 표시
				if let product = viewModel.product {
					VStack(alignment: .leading, spacing: 12) {
						Text(product.name)
							.font(.title)
						Text(product.summary)
							.foregroundStyle(.secondary)
					}
					.padding()
				} else {
					ProgressView()
				}
			}
			.navigationTitle("상품 상세")
		}
		.task {
			viewModel.load()
		}
	}
}
