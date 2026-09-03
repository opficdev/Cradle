//
//  TypedOverrideConfiguration.swift
//  CradleMacros
//
//  Created by opfic on 9/3/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// `@DependencyGraph`의 타입 지정 override opt-in 결과
struct TypedOverrideConfiguration {
	// override 생성 API 추가 여부
	let isEnabled: Bool
}

// `overrides` argument의 직접 작성 Bool literal 검증
func typedOverrideConfiguration(
	from attribute: AttributeSyntax,
	in context: some MacroExpansionContext
) -> TypedOverrideConfiguration? {
	guard case let .argumentList(arguments)? = attribute.arguments else {
		return TypedOverrideConfiguration(isEnabled: false)
	}
	let supplied = arguments.filter { argument in
		argument.label?.identifier?.name == "overrides"
	}
	guard supplied.count <= 1 else {
		context.diagnose(Diagnostic(node: arguments, message: TypedOverrideDiagnostic.invalidConfiguration))
		return nil
	}
	guard let argument = supplied.first else {
		return TypedOverrideConfiguration(isEnabled: false)
	}
	guard let literal = argument.expression.as(BooleanLiteralExprSyntax.self),
		!argument.expression.hasError else {
		context.diagnose(Diagnostic(node: argument.expression, message: TypedOverrideDiagnostic.invalidConfiguration))
		return nil
	}
	return TypedOverrideConfiguration(isEnabled: literal.literal.text == "true")
}
