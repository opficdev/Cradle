//
//  DependencyGraph.swift
//  Cradle
//
//  Created by opfic on 8/29/26.
//

// private `@Provide` factory에서 생성 접근자를 추가할 graph 선언
//
// provider 매개변수의 지역 이름을 등록 생성 접근자와 연결
// `final class` 전용 적용과 initializer·stored property 미변경
@attached(member, names: arbitrary)
public macro DependencyGraph() = #externalMacro(
	module: "CradleMacros",
	type: "DependencyGraphMacro"
)

// `@DependencyGraph` 본체에서 생성 접근자가 호출할 private factory 표시
@attached(peer, names: arbitrary)
public macro Provide() = #externalMacro(
	module: "CradleMacros",
	type: "ProvideMacro"
)
