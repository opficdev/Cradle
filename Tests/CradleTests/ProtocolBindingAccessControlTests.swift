//
//  ProtocolBindingAccessControlTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import Cradle
import CradleConsumerFixture
import Testing

// 외부 모듈의 프로토콜 경로를 명시한 그래프
@DependencyGraph
final class QualifiedProtocolGraph {
	// 전체 모듈 경로를 보존해야 하는 반환 타입
	@Provide
	private func makePublicRepository() -> any CradleConsumerFixture.PublicRepository {
		PublicProtocolGraph().publicRepository
	}
}

// 별도 모듈에서 구체 구현 없이 프로토콜 접근자 사용 확인
@Test
func protocolBindingAllowsExternalContractAccess() {
	// 공개 생성자를 사용하는 외부 소비자
	let graph = PublicProtocolGraph()
	#expect(graph.publicRepository.token == 42)
}

// 실제 모듈 경로가 붙은 프로토콜 반환 타입의 컴파일과 전달 확인
@Test
func protocolBindingPreservesModuleQualifiedReturnType() {
	// 외부 모듈 프로토콜을 등록한 그래프
	let graph = QualifiedProtocolGraph()
	#expect(graph.publicRepository.token == 42)
}
