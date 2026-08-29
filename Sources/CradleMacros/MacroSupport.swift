//
//  MacroSupport.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntax

// `@Provide` factory 접근자 생성용 문법 정보 보관
struct ProviderDescriptor {
	// graph 본체에서 호출할 private factory 이름
	let factoryName: String
	// 생성 접근자가 그대로 노출할 반환 타입
	let returnType: TypeSyntax
	// 반환 타입에서 만든 생성 접근자 이름
	let accessorName: String
}

// 지정한 이름 attribute의 선언 포함 여부 확인
func containsAttribute(named name: String, in attributes: AttributeListSyntax) -> Bool {
	attributes.contains { element in
		guard let attribute = element.as(AttributeSyntax.self) else {
			return false
		}
		return attribute.attributeName.trimmedDescription == name
	}
}

// 구체 명목 반환 타입 마지막 identifier의 접근자 이름 변환
func accessorName(for returnType: TypeSyntax) -> String? {
	guard let identifier = terminalIdentifier(in: returnType) else {
		return nil
	}
	return lowerCamelCase(identifier)
}

// module-qualified 타입을 포함한 마지막 명목 타입 identifier 읽기
private func terminalIdentifier(in returnType: TypeSyntax) -> String? {
	if let identifierType = returnType.as(IdentifierTypeSyntax.self),
		identifierType.genericArgumentClause == nil {
		return identifierType.name.text
	}

	if let memberType = returnType.as(MemberTypeSyntax.self),
		memberType.genericArgumentClause == nil,
		terminalIdentifier(in: memberType.baseType) != nil {
		return memberType.name.text
	}

	return nil
}

// 앞 대문자 묶음을 보존하는 lowerCamelCase 접근자 이름 생성
private func lowerCamelCase(_ name: String) -> String {
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

	let prefix = String(characters.prefix(uppercaseCount - 1)).lowercased()
	return prefix + String(characters.dropFirst(uppercaseCount - 1))
}
