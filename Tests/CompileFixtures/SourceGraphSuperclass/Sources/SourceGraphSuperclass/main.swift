//
//  main.swift
//  SourceGraphSuperclass
//
//  Created by opfic on 9/2/26.
//

import Cradle

// 조합 graph가 받을 source graph
@DependencyGraph
final class SourceGraphSuperclassSource {}

// 매크로가 initializer 호출을 보완하지 않을 superclass
class SourceGraphSuperclass {
	init(token: Int) {
		_ = token
	}
}

// 생성 initializer에 super.init()이 없어 Swift가 거부할 조합 graph
@DependencyGraph(sources: [SourceGraphSuperclassSource.self])
final class SourceGraphSubclass: SourceGraphSuperclass {}
