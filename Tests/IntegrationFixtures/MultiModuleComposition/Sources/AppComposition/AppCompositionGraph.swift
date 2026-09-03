//
//  AppCompositionGraph.swift
//  AppComposition
//
//  Created by opfic on 9/3/26.
//

import Cradle
import Data
import Domain
import Infra
import Persistence

// DataGraph의 Domain 계약을 최종 UseCase로 조합하는 graph
@DependencyGraph(sources: [DataGraph.self])
package final class AppCompositionGraph {
	// DataGraph의 Repository를 주입한 UseCase 등록
	@Provide
	private func makeLoadUserProfileUseCase() -> LoadUserProfileUseCase {
		LoadUserProfileUseCase(repository: dataGraph.userRepository)
	}
}

// 계층 graph의 생성 순서를 소유하는 Composition Root
package enum LayeredAppComposition {
	// leaf graph부터 AppCompositionGraph까지 명시적 조립
	package static func makeGraph() -> AppCompositionGraph {
		// Persistence 등록을 소유할 source graph
		let persistenceGraph = PersistenceGraph()
		// Infra 등록을 소유할 source graph
		let infraGraph = InfraGraph()
		// Persistence와 Infra graph를 보유할 DataGraph
		let dataGraph = DataGraph(
			infraGraph: infraGraph,
			persistenceGraph: persistenceGraph
		)
		return AppCompositionGraph(dataGraph: dataGraph)
	}
}
