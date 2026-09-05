//
//  DiagramConfiguration.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// `@DependencyGraph`의 Mermaid 산출물 제외 표식
struct DiagramConfiguration {
	// plugin 분석 대상 포함 여부
	let isEnabled: Bool
}

// `diagram` 인자의 직접 작성 Bool literal 검증
func diagramConfiguration(
	from attribute: AttributeSyntax,
	in context: some MacroExpansionContext
) -> DiagramConfiguration? {
	guard case let .argumentList(arguments)? = attribute.arguments else {
		return DiagramConfiguration(isEnabled: true)
	}
	let supplied = arguments.filter { argument in
		argument.label?.identifier?.name == "diagram"
	}
	guard supplied.count <= 1 else {
		context.diagnose(Diagnostic(node: arguments, message: DiagramDiagnostic.invalidConfiguration))
		return nil
	}
	guard let argument = supplied.first else {
		return DiagramConfiguration(isEnabled: true)
	}
	guard let literal = argument.expression.as(BooleanLiteralExprSyntax.self),
		!argument.expression.hasError else {
		context.diagnose(Diagnostic(node: argument.expression, message: DiagramDiagnostic.invalidConfiguration))
		return nil
	}
	return DiagramConfiguration(isEnabled: literal.literal.text == "true")
}
