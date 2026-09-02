//
//  RegisteredType.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftSyntax

// 등록 타입의 비교용 정규형
struct RegisteredTypeIdentity: Hashable {
	// 의미 분석 없이 정규화한 타입 철자
	let canonicalText: String
}

// Factory 반환 타입에서 만든 생성 프로퍼티 정보
struct RegisteredType {
	// 생성 프로퍼티와 shared storage가 노출할 반환 타입
	let exposedType: TypeSyntax
	// provider 연결과 중복 검사에 사용할 정규형
	let identity: RegisteredTypeIdentity
	// 반환 타입 마지막 식별자에서 만든 프로퍼티 이름
	let propertyName: String
}

// Factory 반환 타입을 등록 프로퍼티 정보로 변환
func registeredType(for returnType: TypeSyntax) -> RegisteredType? {
	guard !isDirectOptionalType(returnType),
		let propertyName = accessorName(for: returnType) else {
		return nil
	}
	return RegisteredType(
		exposedType: returnType,
		identity: registeredTypeIdentity(for: returnType),
		propertyName: propertyName
	)
}

// 타입 연결 비교용 identity 생성
func registeredTypeIdentity(for type: TypeSyntax) -> RegisteredTypeIdentity {
	let normalized = unwrappedIdentityType(type)
	let text = normalized.tokens(viewMode: .sourceAccurate).map { token in
		token.identifier?.name ?? token.text
	}.joined()
	return RegisteredTypeIdentity(canonicalText: text)
}

// 바깥 괄호와 최상위 any를 제거한 비교 타입
private func unwrappedIdentityType(_ type: TypeSyntax) -> TypeSyntax {
	let type = unwrappedParenthesizedType(type)
	guard let existential = type.as(SomeOrAnyTypeSyntax.self),
		existential.someOrAnySpecifier.tokenKind == .keyword(.any) else {
		return type
	}
	return unwrappedParenthesizedType(existential.constraint)
}

// 의미를 바꾸지 않는 단일 바깥 괄호 재귀 제거
private func unwrappedParenthesizedType(_ type: TypeSyntax) -> TypeSyntax {
	guard let tuple = type.as(TupleTypeSyntax.self),
		tuple.elements.count == 1,
		let element = tuple.elements.first,
		element.firstName == nil,
		element.secondName == nil,
		element.ellipsis == nil else {
		return type
	}
	return unwrappedParenthesizedType(element.type)
}
