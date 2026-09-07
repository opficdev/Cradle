//
//  GraphInputDescriptor.swift
//  CradleMacros
//
//  Created by opfic on 9/7/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// graph 생성자가 보관할 단일 조립 입력 정보
struct GraphInputDescriptor {
	// graph 저장 프로퍼티와 생성자에 사용할 입력 타입
	let type: TypeSyntax

	// graph 입력을 정규화해 수집
	static func from(
		attribute: AttributeSyntax,
		in context: some MacroExpansionContext
	) -> GraphInputDescriptor? {
		guard case let .argumentList(arguments)? = attribute.arguments else {
			return nil
		}
		let inputs = arguments.filter { $0.label?.identifier?.name == "input" }
		guard inputs.count <= 1 else {
			context.diagnose(Diagnostic(node: arguments, message: GraphInputDiagnostic.invalidInput))
			return nil
		}
		guard let input = inputs.first else {
			return nil
		}
		guard let member = input.expression.as(MemberAccessExprSyntax.self),
			member.declName.baseName.text == "self",
			member.declName.argumentNames == nil,
			let base = member.base,
			!input.expression.hasError else {
			context.diagnose(Diagnostic(node: input.expression, message: GraphInputDiagnostic.invalidInput))
			return nil
		}
		let type = TypeSyntax(stringLiteral: base.trimmedDescription)
		guard !type.hasError else {
			context.diagnose(Diagnostic(node: input.expression, message: GraphInputDiagnostic.invalidInput))
			return nil
		}
		return GraphInputDescriptor(type: type)
	}
}

// graph attribute에 직접 작성한 input argument 반환
func graphInputArgument(in attribute: AttributeSyntax) -> LabeledExprSyntax? {
	guard case let .argumentList(arguments)? = attribute.arguments else {
		return nil
	}
	return arguments.first { $0.label?.identifier?.name == "input" }
}

// graph initializer input 선언 제약 진단
enum GraphInputDiagnostic: DiagnosticMessage {
	case invalidInput
	case actorUnsupported
	case sharedGraphUnsupported
	case initializationConflict

	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: String(describing: self))
	}

	var message: String {
		switch self {
		case .invalidInput:
			"`input`은 `Input.self` 형식으로 하나만 지정해야 합니다."
		case .actorUnsupported:
			"initializer input은 `final class` graph에서만 지원합니다."
		case .sharedGraphUnsupported:
			"`@DependencyGraph(.shared)`는 호출자 initializer input을 받을 수 없습니다."
		case .initializationConflict:
			"initializer input graph는 initializer 또는 초기화가 필요한 stored property를 직접 선언할 수 없습니다."
		}
	}

	var severity: DiagnosticSeverity { .error }
}

// Macro가 소유한 input 생성 경로와 충돌하는 member 진단
func diagnoseGraphInputInitializationErrors(
	in members: MemberBlockItemListSyntax,
	context: some MacroExpansionContext
) -> Bool {
	var hasError = false
	for member in members {
		if let initializer = member.decl.as(InitializerDeclSyntax.self) {
			context.diagnose(Diagnostic(node: initializer.initKeyword, message: GraphInputDiagnostic.initializationConflict))
			hasError = true
		}
		guard let variable = member.decl.as(VariableDeclSyntax.self),
			!graphInputHasTypeMemberModifier(variable.modifiers) else {
			continue
		}
		for binding in variable.bindings where requiresStoredPropertyInitialization(binding, in: variable) {
			context.diagnose(Diagnostic(node: binding.pattern, message: GraphInputDiagnostic.initializationConflict))
			hasError = true
		}
	}
	return hasError
}

// graph input 저장 프로퍼티 검사에서 제외할 type member 판별
private func graphInputHasTypeMemberModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
	}
}
