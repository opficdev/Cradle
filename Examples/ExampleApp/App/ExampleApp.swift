//
//  ExampleApp.swift
//  ExampleApp
//
//  Created by opfic on 9/4/26.
//

import SwiftUI

// Cradle 소비 예제의 앱 진입점
@main
@MainActor
struct ExampleApp: App {
	// 앱 수명 동안 graph를 보유할 Composition Root
	private let composition: ExampleAppComposition
	// ViewModel 수명을 맡을 최상위 View
	private let rootView: ProductDetailView

	// Composition Root에서 생성한 ViewModel을 최상위 View에 주입
	init() {
		let composition = ExampleAppComposition()
		self.composition = composition
		rootView = ProductDetailView(
			viewModel: composition.makeProductDetailViewModel(
				productID: ProductID(rawValue: "featured-product")
			)
		)
	}

	// ExampleApp 장면 구성
	var body: some Scene {
		WindowGroup {
			rootView
		}
	}
}
