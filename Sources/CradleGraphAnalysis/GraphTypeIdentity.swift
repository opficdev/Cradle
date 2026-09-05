//
//  GraphTypeIdentity.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntax

// graph 등록과 source 선언을 비교하는 정규 타입 철자
package struct GraphTypeIdentity: Hashable {
	// 의미 분석 없이 정규화한 타입 철자
	package let canonicalText: String
}

// Mermaid node 수명 표기에 사용할 provider 수명
package enum GraphProviderLifetime: String {
	// 프로퍼티 접근마다 Factory를 호출하는 수명
	case transient
	// graph 생성 중 한 번 만들고 보관하는 수명
	case shared
}

// 타입 연결과 정렬에 사용할 정규 identity 생성
package func graphTypeIdentity(for type: TypeSyntax) -> GraphTypeIdentity {
	let normalized = unwrappedGraphIdentityType(type)
	let text = normalized.tokens(viewMode: .sourceAccurate).map { token in
		token.identifier?.name ?? token.text
	}.joined()
	return GraphTypeIdentity(canonicalText: text)
}

// 바깥 괄호와 최상위 any를 제거한 identity 비교 타입
private func unwrappedGraphIdentityType(_ type: TypeSyntax) -> TypeSyntax {
	let type = unwrappedGraphParenthesizedType(type)
	guard let existential = type.as(SomeOrAnyTypeSyntax.self),
		existential.someOrAnySpecifier.tokenKind == .keyword(.any) else {
		return type
	}
	return unwrappedGraphParenthesizedType(existential.constraint)
}

// identity 비교에서 의미를 바꾸지 않는 단일 바깥 괄호 제거
private func unwrappedGraphParenthesizedType(_ type: TypeSyntax) -> TypeSyntax {
	guard let tuple = type.as(TupleTypeSyntax.self),
		tuple.elements.count == 1,
		let element = tuple.elements.first,
		element.firstName == nil,
		element.secondName == nil,
		element.ellipsis == nil else {
		return type
	}
	return unwrappedGraphParenthesizedType(element.type)
}
