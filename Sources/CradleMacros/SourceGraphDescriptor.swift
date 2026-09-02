//
//  SourceGraphDescriptor.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// `sources` 배열 원소에서 만든 source graph 정보
struct SourceGraphDescriptor {
	// 원본 `GraphType.self` 표현식
	let expression: ExprSyntax
	// 저장 프로퍼티와 initializer가 사용할 source graph type
	let type: TypeSyntax
	// source 배열 정렬과 중복 판단용 type identity
	let identity: RegisteredTypeIdentity
	// source graph type에서 만든 저장 프로퍼티 이름
	let propertyName: String

	// 백틱을 제외한 저장 프로퍼티 비교용 식별자
	var propertyIdentifier: String {
		guard propertyName.hasPrefix("`"), propertyName.hasSuffix("`") else {
			return propertyName
		}
		return String(propertyName.dropFirst().dropLast())
	}
}

// `sources` 구문 분석 결과
struct SourceGraphResult {
	// 정규화·정렬한 source graph
	let descriptors: [SourceGraphDescriptor]
	// source 구문 또는 선언 충돌 오류 발생 여부
	let hasError: Bool
}

// `@DependencyGraph`의 `sources` 배열을 source graph descriptor로 변환
func sourceGraphResult(
	from attribute: AttributeSyntax,
	in context: some MacroExpansionContext
) -> SourceGraphResult {
	guard let supplied = attribute.arguments else {
		return SourceGraphResult(descriptors: [], hasError: false)
	}
	guard case let .argumentList(arguments) = supplied else {
		context.diagnose(Diagnostic(node: attribute, message: SourceGraphDiagnostic.invalidSources))
		return SourceGraphResult(descriptors: [], hasError: true)
	}
	if arguments.isEmpty {
		return SourceGraphResult(descriptors: [], hasError: false)
	}
	guard arguments.count == 1,
		let argument = arguments.first,
		argument.label?.identifier?.name == "sources",
		let array = argument.expression.as(ArrayExprSyntax.self),
		!attribute.hasError else {
		context.diagnose(Diagnostic(node: arguments, message: SourceGraphDiagnostic.invalidSources))
		return SourceGraphResult(descriptors: [], hasError: true)
	}
	guard !array.elements.isEmpty else {
		context.diagnose(Diagnostic(node: array, message: SourceGraphDiagnostic.emptySources))
		return SourceGraphResult(descriptors: [], hasError: true)
	}

	var descriptors: [SourceGraphDescriptor] = []
	var hasError = false
	for element in array.elements {
		guard let descriptor = sourceGraphDescriptor(from: element.expression) else {
			context.diagnose(Diagnostic(node: element.expression, message: SourceGraphDiagnostic.invalidSource))
			hasError = true
			continue
		}
		descriptors.append(descriptor)
	}
	let ordered = descriptors.sorted { lhs, rhs in
		lhs.identity.canonicalText < rhs.identity.canonicalText
	}
	return SourceGraphResult(descriptors: ordered, hasError: hasError)
}

// `GraphType.self` source 원소를 descriptor로 변환
private func sourceGraphDescriptor(from expression: ExprSyntax) -> SourceGraphDescriptor? {
	guard let member = expression.as(MemberAccessExprSyntax.self),
		member.declName.baseName.text == "self",
		member.declName.argumentNames == nil,
		let base = member.base,
		!expression.hasError else {
		return nil
	}
	let type = TypeSyntax(stringLiteral: base.trimmedDescription)
	guard !type.hasError,
		let propertyName = accessorName(for: type),
		isValidAccessorName(propertyName) else {
		return nil
	}
	return SourceGraphDescriptor(
		expression: expression,
		type: type,
		identity: registeredTypeIdentity(for: type),
		propertyName: propertyName
	)
}

// source 선언과 graph member의 충돌 진단
func diagnoseSourceGraphErrors(
	in graph: ClassDeclSyntax,
	sources: [SourceGraphDescriptor],
	providerNames: Set<String>,
	memberNames: Set<String>,
	context: some MacroExpansionContext
) -> Bool {
	guard !sources.isEmpty else {
		return false
	}
	let collisionError = diagnoseSourceGraphCollisions(
		sources: sources,
		providerNames: providerNames,
		memberNames: memberNames,
		context: context
	)
	let declarationError = diagnoseSourceGraphMemberErrors(in: graph, context: context)
	return collisionError || declarationError
}

// source type·저장 프로퍼티·기존 member 이름 충돌 진단
private func diagnoseSourceGraphCollisions(
	sources: [SourceGraphDescriptor],
	providerNames: Set<String>,
	memberNames: Set<String>,
	context: some MacroExpansionContext
) -> Bool {
	let duplicateError = diagnoseDuplicateSourceGraphs(sources: sources, context: context)
	let propertyError = diagnoseSourceGraphPropertyCollisions(sources: sources, context: context)
	let memberError = diagnoseSourceGraphMemberCollisions(
		sources: sources,
		providerNames: providerNames,
		memberNames: memberNames,
		context: context
	)
	return duplicateError || propertyError || memberError
}

// 같은 source type의 중복 선언 진단
private func diagnoseDuplicateSourceGraphs(
	sources: [SourceGraphDescriptor],
	context: some MacroExpansionContext
) -> Bool {
	let identityGroups = Dictionary(grouping: sources, by: \.identity)
	var reportedIdentities = Set<RegisteredTypeIdentity>()
	var hasError = false

	for source in sources {
		let identityGroup = identityGroups[source.identity] ?? []
		guard 1 < identityGroup.count,
			reportedIdentities.insert(source.identity).inserted else {
			continue
		}
		for duplicate in identityGroup.dropFirst() {
			context.diagnose(
				Diagnostic(
					node: duplicate.expression,
					message: SourceGraphDiagnostic.duplicateSource(type: duplicate.type.trimmedDescription),
					notes: [
						Note(
							node: Syntax(identityGroup[0].expression),
							message: SourceGraphNote(type: identityGroup[0].type.trimmedDescription)
						)
					]
				)
			)
		}
		hasError = true
	}
	return hasError
}

// 서로 다른 source type의 저장 프로퍼티 이름 충돌 진단
private func diagnoseSourceGraphPropertyCollisions(
	sources: [SourceGraphDescriptor],
	context: some MacroExpansionContext
) -> Bool {
	let propertyGroups = Dictionary(grouping: sources, by: \.propertyIdentifier)
	var reportedProperties = Set<String>()
	var hasError = false

	for source in sources {
		let propertyGroup = propertyGroups[source.propertyIdentifier] ?? []
		guard 1 < propertyGroup.count,
			1 < Set(propertyGroup.map(\.identity)).count,
			reportedProperties.insert(source.propertyIdentifier).inserted else {
			continue
		}
		for collision in propertyGroup.dropFirst() {
			context.diagnose(
				Diagnostic(
					node: collision.expression,
					message: SourceGraphDiagnostic.sourceNameCollision(name: collision.propertyName),
					notes: [
						Note(
							node: Syntax(propertyGroup[0].expression),
							message: SourceGraphNote(type: propertyGroup[0].type.trimmedDescription)
						)
					]
				)
			)
		}
		hasError = true
	}
	return hasError
}

// source 저장 프로퍼티와 기존 graph member 이름 충돌 진단
private func diagnoseSourceGraphMemberCollisions(
	sources: [SourceGraphDescriptor],
	providerNames: Set<String>,
	memberNames: Set<String>,
	context: some MacroExpansionContext
) -> Bool {
	var hasError = false
	for source in sources where memberNames.contains(source.propertyIdentifier)
		|| providerNames.contains(source.propertyIdentifier) {
		context.diagnose(
			Diagnostic(
				node: source.expression,
				message: SourceGraphDiagnostic.sourceNameCollision(name: source.propertyName)
			)
		)
		hasError = true
	}
	return hasError
}

// source graph의 사용자 initializer와 초기값 없는 저장 프로퍼티 진단
private func diagnoseSourceGraphMemberErrors(
	in graph: ClassDeclSyntax,
	context: some MacroExpansionContext
) -> Bool {
	var hasError = false
	for member in graph.memberBlock.members {
		if let initializer = member.decl.as(InitializerDeclSyntax.self) {
			context.diagnose(Diagnostic(node: initializer.initKeyword, message: SourceGraphDiagnostic.userInitializer))
			hasError = true
		}
		guard let variable = member.decl.as(VariableDeclSyntax.self),
			!sourceGraphHasTypeMemberModifier(variable.modifiers) else {
			continue
		}
		for binding in variable.bindings where sourceGraphHasUninitializedStoredProperty(
			binding,
			in: variable
		) {
			context.diagnose(
				Diagnostic(node: binding.pattern, message: SourceGraphDiagnostic.uninitializedStoredProperty)
			)
			hasError = true
		}
	}
	return hasError
}

// 자동 초기화 여부를 반영한 저장 프로퍼티 초기화 필요 여부 판별
private func sourceGraphHasUninitializedStoredProperty(
	_ binding: PatternBindingSyntax,
	in variable: VariableDeclSyntax
) -> Bool {
	guard binding.initializer == nil else {
		return false
	}
	guard !sourceGraphHasAutomaticInitialization(binding, in: variable) else {
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
private func sourceGraphHasAutomaticInitialization(
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

// source graph 저장 프로퍼티 검사에서 제외할 type member 판별
private func sourceGraphHasTypeMemberModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
	}
}

// source 저장 프로퍼티와 생성 initializer 선언 생성
func sourceGraphDeclarations(
	for sources: [SourceGraphDescriptor],
	accessLevel: AccessLevel,
	storage: SharedGraphStorage?
) -> [DeclSyntax] {
	guard !sources.isEmpty else {
		return []
	}
	let properties = sources.map { source in
		DeclSyntax(
			"""
			private let \(raw: source.propertyName): \(raw: source.type.trimmedDescription)
			"""
		)
	}
	let parameters = sources.map { source in
		"\(source.propertyName): \(source.type.trimmedDescription)"
	}.joined(separator: ", ")
	let sourceAssignments = sources.map { source in
		"self.\(source.propertyName) = \(source.propertyName)"
	}
	let assignments = (sourceAssignments + [storage?.initializationAssignment()])
		.compactMap { $0 }
		.joined(separator: "\n")
	let initializer = DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) init(\(raw: parameters)) {
		    \(raw: assignments)
		}
		"""
	)
	return properties + [initializer]
}
