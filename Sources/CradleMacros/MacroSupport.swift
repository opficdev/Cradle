//
//  MacroSupport.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftDiagnostics

// graph 생성 접근자에 적용할 Swift 접근 수준
enum AccessLevel: String {
	case `private`
	case `fileprivate`
	case `internal`
	case `package`
	case `public`
}

// G1 Macro 오류 message 정의
enum CradleMacroDiagnostic: DiagnosticMessage {
	case invalidGraph
	case invalidProvidePlacement
	case invalidProviderDeclaration
	case invalidProviderSignature
	case missingProviderResultOrBody
	case unsupportedProviderResult
	case invalidAccessorName
	case duplicateAccessor
	case existingMemberCollision

	// Cradle Macro diagnostic 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: String(describing: self))
	}

	// compiler diagnostic message
	var message: String {
		switch self {
		case .invalidGraph:
			"`@DependencyGraph`는 비 generic `final class`에만 적용할 수 있습니다."
		case .invalidProvidePlacement:
			"`@Provide`는 `@DependencyGraph` 본체에 직접 선언해야 합니다."
		case .invalidProviderDeclaration:
			"`@Provide` factory는 private instance method여야 합니다."
		case .invalidProviderSignature:
			"`@Provide` factory는 매개변수, generic, type method, `async`, `throws`, "
				+ "`rethrows`를 가질 수 없습니다."
		case .missingProviderResultOrBody:
			"`@Provide` factory는 명시적 반환 타입과 본문이 필요합니다."
		case .unsupportedProviderResult:
			"`@Provide` 반환 타입은 generic argument가 없는 구체 명목 타입이어야 합니다."
		case .invalidAccessorName:
			"`@Provide` 반환 타입에서 유효한 생성 접근자 이름을 만들 수 없습니다."
		case .duplicateAccessor:
			"반환 타입이 만드는 생성 접근자 이름이 중복됩니다."
		case .existingMemberCollision:
			"생성 접근자 이름이 기존 instance member와 충돌합니다."
		}
	}

	// G1 구성 오류 severity
	var severity: DiagnosticSeverity { .error }
}

// `@Provide` factory 접근자 생성용 문법 정보 보관
struct ProviderDescriptor {
	// 오류 위치로 사용할 `@Provide` attribute
	let attribute: AttributeSyntax
	// graph 본체에서 호출할 private factory 이름
	let factoryName: String
	// 생성 접근자가 그대로 노출할 반환 타입
	let returnType: TypeSyntax
	// 반환 타입에서 만든 생성 접근자 이름
	let accessorName: String
}

// 지정한 이름 attribute의 선언 포함 여부 확인
func containsAttribute(named name: String, in attributes: AttributeListSyntax) -> Bool {
	attribute(named: name, in: attributes) != nil
}

// 지정한 이름의 attribute 반환
func attribute(named name: String, in attributes: AttributeListSyntax) -> AttributeSyntax? {
	attributes.compactMap { element in
		element.as(AttributeSyntax.self)
	}.first { attribute in
		attribute.attributeName.trimmedDescription == name
	}
}

// 선언에 붙은 `@Provide` attribute 반환
func provideAttribute(in declaration: some DeclSyntaxProtocol) -> AttributeSyntax? {
	declaration.asProtocol(WithAttributesSyntax.self).flatMap { attributed in
		attribute(named: "Provide", in: attributed.attributes)
	}
}

// graph 선언의 생성 접근자 적용 수준 반환
func accessLevel(of graph: ClassDeclSyntax) -> AccessLevel {
	for modifier in graph.modifiers {
		if let level = AccessLevel(rawValue: modifier.name.text) {
			return level
		}
	}
	return .internal
}

// graph 직접 instance member 이름 수집
func instanceMemberNames(in graph: ClassDeclSyntax) -> Set<String> {
	graph.memberBlock.members.reduce(into: Set<String>()) { names, member in
		if let function = member.decl.as(FunctionDeclSyntax.self),
			!hasTypeMemberModifier(in: function.modifiers),
			function.signature.parameterClause.parameters.isEmpty {
			names.insert(function.name.text)
			return
		}

		if let variable = member.decl.as(VariableDeclSyntax.self),
			!hasTypeMemberModifier(in: variable.modifiers) {
			for binding in variable.bindings {
				guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
					continue
				}
				names.insert(pattern.identifier.text)
			}
		}
	}
}

// type member modifier 포함 여부 확인
private func hasTypeMemberModifier(in modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
	}
}

// 구체 명목 반환 타입 마지막 identifier의 접근자 이름 변환
func accessorName(for returnType: TypeSyntax) -> String? {
	guard let identifier = terminalIdentifier(in: returnType) else {
		return nil
	}
	return lowerCamelCase(identifier)
}

// Swift 예약어와 겹치지 않는 생성 접근자 이름 확인
func isValidAccessorName(_ name: String) -> Bool {
	guard let declaration = try? FunctionDeclSyntax("func \(raw: name)() {}") else {
		return false
	}
	return !declaration.hasError
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
	if !characters[uppercaseCount].isLowercase {
		let prefix = String(characters.prefix(uppercaseCount)).lowercased()
		return prefix + String(characters.dropFirst(uppercaseCount))
	}

	let prefix = String(characters.prefix(uppercaseCount - 1)).lowercased()
	return prefix + String(characters.dropFirst(uppercaseCount - 1))
}
