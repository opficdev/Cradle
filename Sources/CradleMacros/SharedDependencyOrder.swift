//
//  SharedDependencyOrder.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

// shared Factory를 의존성보다 뒤에 배치하는 생성 순서 계산
func sharedDependencyOrder(in providers: [ProviderDescriptor]) -> [ProviderDescriptor] {
	let indices = Dictionary(uniqueKeysWithValues: providers.enumerated().map { index, provider in
		(provider.registrationIdentity, index)
	})
	var visited = Set<Int>()
	var order: [Int] = []

	func visit(_ index: Int) {
		guard visited.insert(index).inserted else {
			return
		}
		for parameter in providers[index].parameters {
			let dependency = indices[parameter.typeIdentity]!
			if providers[dependency].lifetime == .shared {
				visit(dependency)
			}
		}
		order.append(index)
	}

	for index in providers.indices where providers[index].lifetime == .shared {
		visit(index)
	}
	return order.map { providers[$0] }
}
