//
//  GraphDiagram.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/4/26.
//

// Swift source에서 수집한 DependencyGraph Mermaid 표현 정보
package struct GraphDiagram: Hashable {
	// 모듈 안에서 graph를 구별하는 원본 lexical type 경로
	package let lexicalName: String
	// 충돌과 오류 메시지에 사용할 선언 시작 위치
	package let sourceOffset: Int
	// graph가 보유하는 source graph
	package let sources: [GraphDiagramSource]
	// graph가 제공하는 Factory
	package let providers: [GraphDiagramProvider]
}

// graph 생성 경로가 보유한 source graph 정보
package struct GraphDiagramSource: Hashable {
	// graph 저장 프로퍼티 이름
	package let name: String
	// source graph의 원본 타입 표기
	package let typeName: String
	// source graph 선언 연결용 정규 타입 철자
	package let identity: GraphTypeIdentity
}

// graph 안의 provider Factory 표현 정보
package struct GraphDiagramProvider: Hashable {
	// Factory 선언 이름
	package let factoryName: String
	// Factory 반환 타입의 원본 표기
	package let typeName: String
	// provider 연결용 정규 반환 타입 철자
	package let identity: GraphTypeIdentity
	// graph가 Factory 결과를 소유하는 방식
	package let lifetime: GraphProviderLifetime
	// `@External`을 제외한 Factory 매개변수 타입
	package let dependencyIdentities: [GraphTypeIdentity]
	// Factory 본문이 실제로 읽는 source graph 저장 프로퍼티
	package let sourceNames: Set<String>
}
