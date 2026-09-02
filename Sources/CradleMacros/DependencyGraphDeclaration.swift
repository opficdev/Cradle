//
//  DependencyGraphDeclaration.swift
//  CradleMacros
//
//  Created by opfic on 9/3/26.
//

import SwiftSyntax

// `@DependencyGraph` 확장에 필요한 class·actor 공통 선언 정보
struct DependencyGraphDeclaration {
	// 생성 helper에서 사용할 graph 타입 이름
	let name: TokenSyntax
	// 생성 접근자에 적용할 선언 접근 수정자
	let modifiers: DeclModifierListSyntax
	// provider와 기존 member를 읽을 선언 본문
	let memberBlock: MemberBlockSyntax
	// source graph 조합 지원 여부
	let allowsSources: Bool

	// 지원하는 비 generic class·actor 선언을 공통 정보로 변환
	init?(from declaration: some DeclGroupSyntax) {
		if let graph = declaration.as(ClassDeclSyntax.self) {
			guard dependencyGraphIsFinal(graph),
				graph.genericParameterClause == nil,
				graph.genericWhereClause == nil else {
				return nil
			}
			name = graph.name
			modifiers = graph.modifiers
			memberBlock = graph.memberBlock
			allowsSources = true
			return
		}

		if let graph = declaration.as(ActorDeclSyntax.self) {
			guard graph.genericParameterClause == nil,
				graph.genericWhereClause == nil else {
				return nil
			}
			name = graph.name
			modifiers = graph.modifiers
			memberBlock = graph.memberBlock
			allowsSources = false
			return
		}

		return nil
	}
}

// final class graph의 상속 가능성 차단 여부 확인
private func dependencyGraphIsFinal(_ graph: ClassDeclSyntax) -> Bool {
	graph.modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.final)
	}
}

// `@Provide`의 직접 lexical parent가 지원하는 graph 선언인지 확인
func isDependencyGraphContainer(_ declaration: Syntax) -> Bool {
	if let graph = declaration.as(ClassDeclSyntax.self) {
		return containsAttribute(named: "DependencyGraph", in: graph.attributes)
	}
	if let graph = declaration.as(ActorDeclSyntax.self) {
		return containsAttribute(named: "DependencyGraph", in: graph.attributes)
	}
	return false
}
