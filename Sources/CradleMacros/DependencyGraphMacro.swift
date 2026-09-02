//
//  DependencyGraphMacro.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// `@Provide` Factory를 호출하는 반환 타입 기반 생성 프로퍼티 추가
struct DependencyGraphMacro: MemberMacro {
	// graph 본체의 유효한 Factory별 transient 생성 프로퍼티 생성
	static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let graph = DependencyGraphDeclaration(from: declaration) else {
			context.diagnose(Diagnostic(node: node, message: CradleMacroDiagnostic.invalidGraph))
			return []
		}

		let sourceResult = sourceGraphResult(from: node, in: context)
		guard let sources = acceptedSourceDescriptors(for: graph, from: node, result: sourceResult, in: context) else {
			return []
		}

		let providerResult = providers(in: graph.memberBlock.members, context: context)
		let graphAccess = accessLevel(of: graph.modifiers)
		let hasDeclarationError = hasInitialDeclarationError(
			in: graph.memberBlock.members,
			sources: sources,
			providers: providerResult.descriptors,
			context: context
		)

		guard !providerResult.hasError,
			!hasDeclarationError else {
			return []
		}
		let propertyNames = propertyNames(for: providerResult.descriptors)
		guard providerConnectionsAreValid(
			in: providerResult.descriptors,
			propertyNames: propertyNames,
			context: context
		) else {
			return []
		}
		let storage = sharedStorage(
			for: providerResult.descriptors,
			graphName: graph.name,
			sources: sources,
			propertyNames: propertyNames,
			in: context
		)

		let sourceDeclarations = graph.allowsSources ? sourceGraphDeclarations(
			for: sources,
			accessLevel: graphAccess,
			storage: storage
		) : []
		return sourceDeclarations + propertyDeclarations(
			for: providerResult.descriptors,
			accessLevel: graphAccess,
			propertyNames: propertyNames,
			storage: storage
		)
	}

	// class source 조합과 actor source 금지 규칙을 반영한 source descriptor 반환
	private static func acceptedSourceDescriptors(
		for graph: DependencyGraphDeclaration,
		from attribute: AttributeSyntax,
		result: SourceGraphResult,
		in context: some MacroExpansionContext
	) -> [SourceGraphDescriptor]? {
		guard !result.hasError else {
			return nil
		}
		guard graph.allowsSources || result.descriptors.isEmpty else {
			guard let sources = sourceGraphArgumentExpression(in: attribute) else {
				return nil
			}
			context.diagnose(
				Diagnostic(node: sources, message: ActorGraphDiagnostic.sourcesUnsupported)
			)
			return nil
		}
		return result.descriptors
	}

	// source 선언과 Factory 생성 프로퍼티 선언 충돌 진단
	private static func hasInitialDeclarationError(
		in members: MemberBlockItemListSyntax,
		sources: [SourceGraphDescriptor],
		providers: [ProviderDescriptor],
		context: some MacroExpansionContext
	) -> Bool {
		let memberNames = instanceMemberNames(in: members)
		let sourceError = diagnoseSourceGraphErrors(
			in: members,
			sources: sources,
			providerNames: Set(providers.map(\.propertyIdentifier)),
			memberNames: memberNames,
			context: context
		)
		let propertyError = diagnosePropertyNameErrors(
			in: providers,
			memberNames: memberNames,
			context: context
		)
		return sourceError || propertyError
	}

	// Factory 매개변수·shared 참조·순환 연결 진단
	private static func providerConnectionsAreValid(
		in providers: [ProviderDescriptor],
		propertyNames: [RegisteredTypeIdentity: String],
		context: some MacroExpansionContext
	) -> Bool {
		guard !diagnoseProviderParameterErrors(
			in: providers,
			propertyNames: propertyNames,
			context: context
		) else {
			return false
		}
		guard !diagnoseSharedProviderReferenceErrors(in: providers, context: context) else {
			return false
		}
		return !diagnoseCircularDependency(in: providers, context: context)
	}

	// 첫 순환의 닫는 매개변수와 경로에 포함된 원본 등록 위치 진단
	private static func diagnoseCircularDependency(
		in providers: [ProviderDescriptor],
		context: some MacroExpansionContext
	) -> Bool {
		guard let cycle = firstCircularDependency(in: providers) else {
			return false
		}
		let path = cycle.providerIndices.map { providers[$0].propertyIdentifier }
		let notes = cycle.providerIndices.map { index in
			Note(
				node: Syntax(providers[index].attribute),
				message: CircularDependencyProviderNote(
					factoryName: providers[index].factoryName,
					accessorIdentifier: providers[index].propertyIdentifier
				)
			)
		}
		context.diagnose(
			Diagnostic(
				node: cycle.closingParameter.type,
				message: CircularDependencyDiagnostic(accessorIdentifiers: path + [path[0]]),
				notes: notes
			)
		)
		return true
	}

	// 등록 타입 중복·생성 프로퍼티 이름·기존 member 충돌 진단
	private static func diagnosePropertyNameErrors(
		in providers: [ProviderDescriptor],
		memberNames: Set<String>,
		context: some MacroExpansionContext
	) -> Bool {
		let registrationGroups = Dictionary(grouping: providers, by: \.registrationIdentity)
		let propertyGroups = Dictionary(grouping: providers, by: \.propertyIdentifier)
		var reportedRegistrations = Set<RegisteredTypeIdentity>()
		var reportedProperties = Set<String>()
		var hasError = false

		for provider in providers {
			let identifier = provider.propertyIdentifier
			let registrationGroup = registrationGroups[provider.registrationIdentity] ?? []
			let propertyGroup = propertyGroups[identifier] ?? []
			let group: [ProviderDescriptor]
			let diagnostic: DuplicateRegistrationDiagnostic
			let shouldReport: Bool
			if 1 < registrationGroup.count {
				group = registrationGroup
				diagnostic = DuplicateRegistrationDiagnostic(registrationType: provider.returnType.trimmedDescription)
				shouldReport = reportedRegistrations.insert(provider.registrationIdentity).inserted
			} else {
				group = propertyGroup
				diagnostic = DuplicateRegistrationDiagnostic(accessorIdentifier: identifier)
				shouldReport = 1 < propertyGroup.count && reportedProperties.insert(identifier).inserted
			}
			if shouldReport {
				let notes = group.map { registration in
					Note(
						node: Syntax(registration.attribute),
						message: DuplicateRegistrationProviderNote(
							factoryName: registration.factoryName,
							returnType: registration.returnType.trimmedDescription
						)
					)
				}
				context.diagnose(
					Diagnostic(
						node: provider.returnType,
						message: diagnostic,
						notes: notes
					)
				)
				hasError = true
			}
			if memberNames.contains(provider.propertyIdentifier) {
				context.diagnose(Diagnostic(node: provider.attribute, message: CradleMacroDiagnostic.existingMemberCollision))
				hasError = true
			}
		}

		return hasError
	}

	// 등록 타입 집합에 없는 Factory 매개변수 연결 진단
	private static func diagnoseProviderParameterErrors(
		in providers: [ProviderDescriptor],
		propertyNames: [RegisteredTypeIdentity: String],
		context: some MacroExpansionContext
	) -> Bool {
		var hasError = false

		for provider in providers {
			for parameter in provider.parameters where propertyNames[parameter.typeIdentity] == nil {
				context.diagnose(
					Diagnostic(
						node: parameter.type,
						message: MissingRegistrationDiagnostic(
							factoryName: provider.factoryName,
							registrationType: parameter.type.trimmedDescription
						),
						notes: [
							Note(
								node: Syntax(provider.attribute),
								message: MissingRegistrationProviderNote(factoryName: provider.factoryName)
							)
						]
					)
				)
				hasError = true
			}
		}

		return hasError
	}

	// shared Factory가 graph 초기화 뒤에 만들어지는 transient 등록을 요구하는지 확인
	private static func diagnoseSharedProviderReferenceErrors(
		in providers: [ProviderDescriptor],
		context: some MacroExpansionContext
	) -> Bool {
		let registrations = Dictionary(uniqueKeysWithValues: providers.map { provider in
			(provider.registrationIdentity, provider)
		})
		var hasError = false

		for provider in providers where provider.lifetime == .shared {
			for parameter in provider.parameters {
				guard let dependency = registrations[parameter.typeIdentity],
					dependency.lifetime == .transient else {
					continue
				}
				context.diagnose(
					Diagnostic(
						node: parameter.type,
						message: InvalidSharedProviderReferenceDiagnostic()
					)
				)
				hasError = true
			}
		}

		return hasError
	}
}

// 등록 타입 identity와 생성 접근자 이름 연결 생성
private func propertyNames(for providers: [ProviderDescriptor]) -> [RegisteredTypeIdentity: String] {
	Dictionary(uniqueKeysWithValues: providers.map { ($0.registrationIdentity, $0.propertyName) })
}

// graph 본체의 `@Provide` Factory 검증과 수집
private func providers(
	in members: MemberBlockItemListSyntax,
	context: some MacroExpansionContext
) -> (descriptors: [ProviderDescriptor], hasError: Bool) {
	var hasError = false
	var descriptors: [ProviderDescriptor] = []

	for member in members {
		guard let attribute = provideAttribute(in: member.decl) else {
			continue
		}
		guard let function = member.decl.as(FunctionDeclSyntax.self) else {
			context.diagnose(Diagnostic(node: attribute, message: CradleMacroDiagnostic.invalidProviderDeclaration))
			hasError = true
			continue
		}
		guard let provider = providerDescriptor(from: function, attribute: attribute, in: context) else {
			hasError = true
			continue
		}
		descriptors.append(provider)
	}

	return (descriptors, hasError)
}

// shared 등록이 있을 때만 graph 전용 저장소 생성
private func sharedStorage(
	for providers: [ProviderDescriptor],
	graphName: TokenSyntax,
	sources: [SourceGraphDescriptor],
	propertyNames: [RegisteredTypeIdentity: String],
	in context: some MacroExpansionContext
) -> SharedGraphStorage? {
	let sharedProviders = providers.filter { $0.lifetime == .shared }
	guard !sharedProviders.isEmpty else {
		return nil
	}
	return SharedGraphStorage(
		graphName: graphName,
		providers: sharedProviders,
		sources: sources,
		propertyNames: propertyNames,
		in: context
	)
}

// shared 저장소와 transient Factory 호출을 구분한 생성 프로퍼티 선언 생성
private func propertyDeclarations(
	for providers: [ProviderDescriptor],
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: SharedGraphStorage?
) -> [DeclSyntax] {
	let properties = providers.map { provider in
		let propertySignature = "\(accessLevel.rawValue) var \(provider.propertyName)"
		if provider.lifetime == .shared, let storage {
			return DeclSyntax(
				"""
				\(raw: propertySignature): \(raw: provider.returnType.trimmedDescription) {
				    \(raw: storage.valueReference(for: provider))
				}
				"""
			)
		}
		let arguments = provider.parameters.map { parameter in
			parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity]!)
		}.joined(separator: ", ")

		return DeclSyntax(
			"""
			\(raw: propertySignature): \(raw: provider.returnType.trimmedDescription) {
			    \(raw: provider.factoryName)(\(raw: arguments))
			}
			"""
		)
	}
	return (storage?.declarations() ?? []) + properties
}
