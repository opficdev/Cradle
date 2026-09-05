//
//  GraphAccessorName.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// source graph 저장 프로퍼티 이름과 provider 접근자 이름 생성
package func graphAccessorName(for type: TypeSyntax) -> String? {
	let parenthesizedType = unwrappedGraphAccessorType(type)
	let type = if let existential = parenthesizedType.as(SomeOrAnyTypeSyntax.self),
		existential.someOrAnySpecifier.tokenKind == .keyword(.any) {
		unwrappedGraphAccessorType(existential.constraint)
	} else {
		parenthesizedType
	}
	guard let identifier = graphTerminalIdentifier(in: type) else {
		return nil
	}
	return graphLowerCamelCase(identifier)
}

// Swift 예약어와 겹치지 않는 graph 접근자 이름 확인
package func graphHasValidAccessorName(_ name: String) -> Bool {
	guard let declaration = try? FunctionDeclSyntax("func \(raw: name)() {}") else {
		return false
	}
	return !declaration.hasError
}

// module-qualified 타입을 포함한 마지막 명목 타입 identifier 읽기
private func graphTerminalIdentifier(in type: TypeSyntax) -> String? {
	if let identifier = type.as(IdentifierTypeSyntax.self) {
		return identifier.name.text
	}
	if let member = type.as(MemberTypeSyntax.self),
		graphTerminalIdentifier(in: member.baseType) != nil {
		return member.name.text
	}
	return nil
}

// 프로퍼티 이름 분석에서 단일 바깥 괄호 제거
private func unwrappedGraphAccessorType(_ type: TypeSyntax) -> TypeSyntax {
	guard let tuple = type.as(TupleTypeSyntax.self),
		tuple.elements.count == 1,
		let element = tuple.elements.first,
		element.firstName == nil,
		element.secondName == nil,
		element.ellipsis == nil else {
		return type
	}
	return unwrappedGraphAccessorType(element.type)
}

// 앞 대문자 묶음을 보존하는 lowerCamelCase 접근자 이름 생성
private func graphLowerCamelCase(_ name: String) -> String {
	let characters = Array(name)
	guard let first = characters.first, first.isUppercase else {
		return name
	}

	let uppercaseCount = characters.prefix(while: { $0.isUppercase }).count
	if uppercaseCount == characters.count {
		return name.lowercased()
	}
	if uppercaseCount == 1 {
		return String(first).lowercased() + String(characters.dropFirst())
	}
	if !characters[uppercaseCount].isLowercase {
		let prefix = String(characters.prefix(uppercaseCount)).lowercased()
		return prefix + String(characters.dropFirst(uppercaseCount))
	}

	let prefix = String(characters.prefix(uppercaseCount - 1)).lowercased()
	return prefix + String(characters.dropFirst(uppercaseCount - 1))
}
