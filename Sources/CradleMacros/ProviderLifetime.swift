//
//  ProviderLifetime.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// 등록 인자에서 결정한 Factory 결과 수명
enum ProviderLifetime {
	// 프로퍼티 접근마다 Factory를 호출하는 명시 수명
	case transient
	// graph 생성 중 한 번 만들고 저장하는 기본 수명
	case shared
}

// 표현식 평가 없이 인자 생략 또는 직접 작성한 lifetime case만 허용
func providerLifetime(
	from attribute: AttributeSyntax,
	in context: some MacroExpansionContext
) -> ProviderLifetime? {
	guard let supplied = attribute.arguments else {
		return .shared
	}
	guard case let .argumentList(arguments) = supplied else {
		context.diagnose(Diagnostic(node: attribute, message: InvalidProviderLifetimeDiagnostic()))
		return nil
	}
	if arguments.isEmpty {
		return .shared
	}
	guard arguments.count == 1,
		let argument = arguments.first,
		argument.label == nil,
		let member = argument.expression.as(MemberAccessExprSyntax.self),
		member.base == nil,
		member.declName.argumentNames == nil,
		let name = member.declName.baseName.identifier?.name,
		name == "shared" || name == "transient",
		!attribute.hasError else {
		context.diagnose(Diagnostic(node: arguments, message: InvalidProviderLifetimeDiagnostic()))
		return nil
	}
	return member.declName.baseName.identifier?.name == "shared" ? .shared : .transient
}
