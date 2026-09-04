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

// Cradle Macro 오류 message 정의
enum CradleMacroDiagnostic: DiagnosticMessage {
	case invalidGraph
	case invalidProvidePlacement
	case invalidProviderDeclaration
	case invalidProviderSignature
	case invalidProviderParameter
	case missingProviderResult
	case unsupportedProviderResult
	case invalidAccessorName
	case existingMemberCollision

	// Cradle Macro diagnostic 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: String(describing: self))
	}

	// compiler diagnostic message
	var message: String {
		switch self {
		case .invalidGraph:
			"`@DependencyGraph`는 비 generic `final class` 또는 비 generic `actor`에만 적용할 수 있습니다."
		case .invalidProvidePlacement:
			"`@Provide`는 `@DependencyGraph` 본체에 직접 선언해야 합니다."
		case .invalidProviderDeclaration:
			"`@Provide` factory는 private instance method여야 합니다."
		case .invalidProviderSignature:
			"`@Provide` factory는 generic, type method, `async`, `throws`, "
				+ "`rethrows`를 가질 수 없습니다."
		case .invalidProviderParameter:
			"`@Provide` Factory 매개변수는 지원하는 형식이어야 합니다."
		case .missingProviderResult:
			"`@Provide` factory는 명시적 반환 타입이 필요합니다."
		case .unsupportedProviderResult:
			"`@Provide` 반환 타입은 프로퍼티 이름을 만들 수 있는 명목 타입 또는 `any`로 표시한 단일 프로토콜 타입이어야 합니다."
		case .invalidAccessorName:
			"`@Provide` 등록 타입에서 유효한 프로퍼티 이름을 만들 수 없습니다."
		case .existingMemberCollision:
			"생성 프로퍼티 이름이 기존 인스턴스 멤버와 충돌합니다."
		}
	}

	// Cradle 구성 오류 severity
	var severity: DiagnosticSeverity { .error }
}

// provider factory 인자 생성용 매개변수 정보 보관
struct ProviderParameterDescriptor {
	// 원본 provider 매개변수
	let parameter: FunctionParameterSyntax?
	// 원래 provider의 외부 인자 레이블
	let externalLabel: String?
	// 원본 Factory 본문과 진단에 사용할 지역 이름
	let localName: String
	// 누락 오류를 표시할 원본 지역 이름 토큰
	let localNameToken: TokenSyntax
	// 타입 기반 provider 연결에 사용할 원본 타입
	let type: TypeSyntax
	// 타입 철자 비교용 정규형
	let typeIdentity: RegisteredTypeIdentity
	// graph 생성 메서드 호출자가 전달할 입력 표시
	let externalAttribute: AttributeSyntax?

	// 직접 생성하는 기존 테스트와 원본 구문을 함께 지원하는 초기화
	init(
		parameter: FunctionParameterSyntax? = nil,
		externalLabel: String?,
		localName: String,
		localNameToken: TokenSyntax,
		type: TypeSyntax,
		typeIdentity: RegisteredTypeIdentity,
		externalAttribute: AttributeSyntax? = nil
	) {
		self.parameter = parameter
		self.externalLabel = externalLabel
		self.localName = localName
		self.localNameToken = localNameToken
		self.type = type
		self.typeIdentity = typeIdentity
		self.externalAttribute = externalAttribute
	}

	// graph 등록 대신 호출자가 전달하는 매개변수 여부
	var isExternal: Bool { externalAttribute != nil }

	// 외부 인자 레이블을 보존한 원본 Factory 인자
	func factoryArgument(propertyName: String?, qualifyingGraphMember: Bool = false) -> String {
		let value = factoryValue(
			propertyName: propertyName,
			qualifyingGraphMember: qualifyingGraphMember
		)
		guard let externalLabel else {
			return value
		}
		return "\(externalLabel): \(value)"
	}

	// graph 의존성 또는 호출자 입력의 Factory 값 표현
	func factoryValue(propertyName: String?, qualifyingGraphMember: Bool = false) -> String {
		guard !isExternal else {
			return localNameToken.trimmedDescription
		}
		let value = propertyName!
		return qualifyingGraphMember ? "self.\(value)" : value
	}

	// `@External`을 제거하고 원래 선언을 보존한 생성 메서드 매개변수
	func externalMethodParameter() -> String? {
		guard isExternal else {
			return nil
		}
		guard var parameter else {
			return nil
		}
		parameter.attributes = parameter.attributes.filter { element in
			guard let attribute = element.as(AttributeSyntax.self) else {
				return true
			}
			return !isExternalAttribute(attribute)
		}
		parameter.trailingComma = nil
		return parameter.trimmedDescription
	}

	// initializer에 전달할 원본 지역 이름
	func initializerArgument() -> String {
		guard let externalLabel else {
			return localNameToken.trimmedDescription
		}
		return "\(externalLabel): \(localNameToken.trimmedDescription)"
	}
}

// 지원하는 provider 매개변수를 호출문 생성 정보로 변환
func providerParameterDescriptors(
	from parameters: FunctionParameterListSyntax
) -> [ProviderParameterDescriptor]? {
	// provider factory 매개변수별 호출 정보
	var descriptors: [ProviderParameterDescriptor] = []

	for parameter in parameters {
		// 두 이름 매개변수를 포함한 지역 이름 token
		let name = parameter.secondName ?? parameter.firstName
		// 백틱을 제외한 실제 연결 식별자
		let localName = name.identifier?.name ?? name.text
		guard providerParameterIsSupported(parameter), localName != "_" else {
			return nil
		}
		// 백틱 표기를 보존한 외부 인자 레이블
		let label = parameter.firstName.trimmedDescription
		let external = externalAttribute(in: parameter.attributes)
		descriptors.append(
			ProviderParameterDescriptor(
				parameter: parameter,
				externalLabel: label == "_" ? nil : label,
				localName: localName,
				localNameToken: name,
				type: parameter.type,
				typeIdentity: registeredTypeIdentity(for: parameter.type),
				externalAttribute: external
			)
		)
	}

	return descriptors
}

// 기본 provider와 외부 입력에 공통으로 허용할 매개변수 형식 확인
func providerParameterIsSupported(_ parameter: FunctionParameterSyntax) -> Bool {
	let hasUnsupportedSpecifier = parameter.type.tokens(viewMode: .sourceAccurate).contains { token in
		token.tokenKind == .keyword(.inout) || token.tokenKind == .keyword(.some)
	}
	let attributes = parameter.type.as(AttributedTypeSyntax.self)?.attributes ?? []
	let hasAutoclosure = attributes.contains { element in
		guard let attribute = element.as(AttributeSyntax.self),
			let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
			return false
		}
		return identifier.name.identifier?.name == "autoclosure"
	}
	return parameter.defaultValue == nil
		&& parameter.ellipsis == nil
		&& !hasUnsupportedSpecifier
		&& !hasAutoclosure
		&& !isDirectOptionalType(parameter.type)
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
func accessLevel(of modifiers: DeclModifierListSyntax) -> AccessLevel {
	for modifier in modifiers {
		if let level = AccessLevel(rawValue: modifier.name.text) {
			return level
		}
	}
	return .internal
}

// graph 직접 instance member 이름 수집
func instanceMemberNames(in members: MemberBlockItemListSyntax) -> Set<String> {
	members.reduce(into: Set<String>()) { names, member in
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

// 명목 타입과 단일 프로토콜 반환 타입의 접근자 이름 생성
func accessorName(for returnType: TypeSyntax) -> String? {
	// 바깥 괄호와 최상위 any 표기만 제거한 이름 분석용 타입
	let parenthesizedType = unwrappedAccessorType(returnType)
	let type = if let existential = parenthesizedType.as(SomeOrAnyTypeSyntax.self),
		existential.someOrAnySpecifier.tokenKind == .keyword(.any) {
		unwrappedAccessorType(existential.constraint)
	} else {
		parenthesizedType
	}
	guard let identifier = terminalIdentifier(in: type) else {
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
	if let identifierType = returnType.as(IdentifierTypeSyntax.self) {
		return identifierType.name.text
	}

	if let memberType = returnType.as(MemberTypeSyntax.self),
		terminalIdentifier(in: memberType.baseType) != nil {
		return memberType.name.text
	}

	return nil
}

// 프로퍼티 이름 분석에서 단일 바깥 괄호 제거
private func unwrappedAccessorType(_ type: TypeSyntax) -> TypeSyntax {
	guard let tuple = type.as(TupleTypeSyntax.self),
		tuple.elements.count == 1,
		let element = tuple.elements.first,
		element.firstName == nil,
		element.secondName == nil,
		element.ellipsis == nil else {
		return type
	}
	return unwrappedAccessorType(element.type)
}

// 직접 작성한 Optional 타입 문법 확인
func isDirectOptionalType(_ type: TypeSyntax) -> Bool {
	let type = unwrappedAccessorType(type)
	if type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
		return true
	}
	if let identifier = type.as(IdentifierTypeSyntax.self) {
		return identifier.name.identifier?.name == "Optional"
			&& identifier.genericArgumentClause?.arguments.count == 1
	}
	if let member = type.as(MemberTypeSyntax.self),
		member.name.identifier?.name == "Optional",
		member.genericArgumentClause?.arguments.count == 1,
		let base = member.baseType.as(IdentifierTypeSyntax.self) {
		return base.name.identifier?.name == "Swift"
	}
	return false
}

// 생성 initializer가 값을 대입해야 하는 저장 프로퍼티 판별
func requiresStoredPropertyInitialization(
	_ binding: PatternBindingSyntax,
	in variable: VariableDeclSyntax
) -> Bool {
	guard binding.initializer == nil else {
		return false
	}
	guard !hasAutomaticStoredPropertyInitialization(binding, in: variable) else {
		return false
	}
	guard let accessorBlock = binding.accessorBlock else {
		return true
	}
	guard case let .accessors(accessors) = accessorBlock.accessors else {
		return false
	}
	return accessors.allSatisfy { accessor in
		let name = accessor.accessorSpecifier.text
		return name == "willSet" || name == "didSet"
	}
}

// Optional var와 property wrapper 선언의 Swift 자동 초기화 판별
private func hasAutomaticStoredPropertyInitialization(
	_ binding: PatternBindingSyntax,
	in variable: VariableDeclSyntax
) -> Bool {
	guard variable.attributes.isEmpty else {
		return true
	}
	guard variable.bindingSpecifier.tokenKind == .keyword(.var),
		let type = binding.typeAnnotation?.type else {
		return false
	}
	return isDirectOptionalType(type)
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
