//
//  DependencyGraph.swift
//  Cradle
//
//  Created by opfic on 8/29/26.
//

// private `@Provide` Factory에서 생성 접근자를 추가할 final class·actor graph 선언
// 명목 타입과 `any Protocol` 반환 타입을 보존한 생성 접근자 추가
// 모듈 경로가 붙은 프로토콜도 마지막 타입 이름을 기준으로 접근자 이름 생성
//
// provider 매개변수의 지역 이름을 등록 생성 접근자와 연결
// final class `sources` source graph 저장 프로퍼티와 생성 initializer 추가
// `overrides: true` graph의 인스턴스별 Factory 선택 builder와 생성 경로 추가
// source·override가 없는 graph의 initializer·stored property 미변경
@attached(member, names: arbitrary)
public macro DependencyGraph(
	sources: [Any.Type] = [],
	overrides: Bool = false,
	diagram: Bool = true
) = #externalMacro(
	module: "CradleMacros",
	type: "DependencyGraphMacro"
)

// `@DependencyGraph` 본체에서 생성 접근자가 호출할 private factory 표시
@attached(peer, names: arbitrary)
@attached(body)
public macro Provide() = #externalMacro(
	module: "CradleMacros",
	type: "ProvideMacro"
)

// `.shared`로 graph가 Factory 결과를 즉시 소유하도록 표시
@attached(peer, names: arbitrary)
@attached(body)
public macro Provide(_ lifetime: DependencyLifetime) = #externalMacro(
	module: "CradleMacros",
	type: "ProvideMacro"
)
