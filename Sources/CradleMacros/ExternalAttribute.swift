//
//  ExternalAttribute.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntax

// `External`과 `Cradle.External` marker 반환
func externalAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
	attributes.compactMap { element in
		element.as(AttributeSyntax.self)
	}.first(where: isExternalAttribute)
}

// Cradle 외부 입력 marker의 정확한 구문 확인
func isExternalAttribute(_ attribute: AttributeSyntax) -> Bool {
	if let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) {
		return identifier.name.identifier?.name == "External"
	}
	guard let member = attribute.attributeName.as(MemberTypeSyntax.self),
		member.name.identifier?.name == "External",
		let module = member.baseType.as(IdentifierTypeSyntax.self) else {
		return false
	}
	return module.name.identifier?.name == "Cradle"
}
