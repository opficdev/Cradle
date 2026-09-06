//
//  DependencyGraphLifetimeConfiguration.swift
//  CradleMacros
//
//  Created by opfic on 9/6/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// `@DependencyGraph`의 graph 보유 범위 설정
enum DependencyGraphLifetimeConfiguration {
	// graph마다 독립적으로 생성하는 기본 범위
	case instance
	// 정적 접근점으로 프로세스 동안 보유하는 범위
	case shared

	// static 접근점 생성 여부
	var createsSharedGraph: Bool {
		self == .shared
	}
}

// 첫 위치 인자의 직접 `.instance`·`.shared` 표기 검증
func dependencyGraphLifetimeConfiguration(
	from attribute: AttributeSyntax,
	in context: some MacroExpansionContext
) -> DependencyGraphLifetimeConfiguration? {
	guard case let .argumentList(arguments)? = attribute.arguments else {
		return .instance
	}
	let positional = arguments.filter { $0.label == nil }
	guard positional.count <= 1 else {
		context.diagnose(Diagnostic(node: arguments, message: DependencyGraphLifetimeDiagnostic.invalidLifetime))
		return nil
	}
	guard let argument = positional.first else {
		return .instance
	}
	guard arguments.first?.label == nil,
		let member = argument.expression.as(MemberAccessExprSyntax.self),
		member.base == nil,
		member.declName.argumentNames == nil,
		!argument.expression.hasError else {
		context.diagnose(Diagnostic(node: argument.expression, message: DependencyGraphLifetimeDiagnostic.invalidLifetime))
		return nil
	}
	switch member.declName.baseName.identifier?.name ?? member.declName.baseName.text {
	case "instance":
		return .instance
	case "shared":
		return .shared
	default:
		context.diagnose(Diagnostic(node: argument.expression, message: DependencyGraphLifetimeDiagnostic.invalidLifetime))
		return nil
	}
}

// `.shared` 진단에 사용할 첫 위치 인자 반환
func dependencyGraphLifetimeArgument(in attribute: AttributeSyntax) -> ExprSyntax? {
	guard case let .argumentList(arguments)? = attribute.arguments,
		let argument = arguments.first,
		argument.label == nil else {
		return nil
	}
	return argument.expression
}
