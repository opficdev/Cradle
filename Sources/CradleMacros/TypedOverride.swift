// swiftlint:disable file_length
//
//  TypedOverride.swift
//  CradleMacros
//
//  Created by opfic on 9/3/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftDiagnostics
import SwiftSyntaxMacros

// override 상태와 생성 코드를 연결할 Factory별 정보
private struct TypedOverrideProvider {
	// 원본 등록 정보
	let provider: ProviderDescriptor
	// graph 내부 선택 enum 이름
	let stateName: TokenSyntax
	// builder와 graph 저장소가 공유할 선택 상태 이름
	let storageName: TokenSyntax
	// actor graph의 교체 Factory 동시성 경계 여부
	let requiresSendableFactory: Bool

	// Factory 함수 값 형식
	var factoryType: String {
		let parameters = provider.parameters.map { parameter in
			parameter.type.trimmedDescription
		}.joined(separator: ", ")
		let sendable = requiresSendableFactory ? "@Sendable " : ""
		return "\(sendable)(\(parameters)) -> \(provider.returnType.trimmedDescription)"
	}
}

// source 없는 non-public class graph의 override 선언 생성
// swiftlint:disable:next function_parameter_count
func typedOverrideDeclarations(
	for graph: DependencyGraphDeclaration,
	providers: [ProviderDescriptor],
	sources: [SourceGraphDescriptor],
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: SharedGraphStorage?,
	in context: some MacroExpansionContext
) -> [DeclSyntax] {
	let overrides = providers.map { provider in
		TypedOverrideProvider(
			provider: provider,
			stateName: typedOverrideUniqueName("TypedOverrideState", in: context),
			storageName: typedOverrideUniqueName("typedOverrideState", in: context),
			requiresSendableFactory: graph.isActor
		)
	}
	let builderName = TokenSyntax.identifier("OverrideBuilder")
	let shared = overrides.filter { $0.provider.lifetime == .shared }
	let transient = overrides.filter { $0.provider.lifetime == .transient }
	let sharedStorage = TypedOverrideSharedStorage(
		graphName: graph.name,
		builderName: builderName,
		providers: shared,
		sources: sources,
		propertyNames: propertyNames,
		in: context
	)
	return overrides.map(selectionDeclaration)
			+ [
			builderDeclaration(
				named: builderName,
				graph: graph,
				providers: overrides,
				sources: sources,
				accessLevel: accessLevel
				)
			]
		+ [overrideEntryPoint(named: builderName, providers: overrides, accessLevel: accessLevel)]
		+ graphInitializers(
			graphName: graph.name,
			builderName: builderName,
			providers: overrides,
			sources: sources,
			transient: transient,
			storage: sharedStorage,
			accessLevel: accessLevel,
			isActor: graph.isActor
		)
		+ typedOverridePropertyDeclarations(
			providers: overrides,
			sources: sources,
			accessLevel: accessLevel,
			propertyNames: propertyNames,
			storage: sharedStorage
		)
}

// Macro가 소유하는 생성 경로와 충돌하는 사용자 선언 진단
func diagnoseTypedOverrideInitializationErrors(
	in members: MemberBlockItemListSyntax,
	context: some MacroExpansionContext
) -> Bool {
	var hasError = false
	for member in members {
		if let initializer = member.decl.as(InitializerDeclSyntax.self) {
			context.diagnose(Diagnostic(node: initializer.initKeyword, message: TypedOverrideDiagnostic.userInitializer))
			hasError = true
		}
		guard let variable = member.decl.as(VariableDeclSyntax.self),
			!typedOverrideHasTypeMemberModifier(variable.modifiers) else {
			continue
		}
		for binding in variable.bindings where typedOverrideRequiresInitialization(binding) {
			context.diagnose(Diagnostic(node: binding.pattern, message: TypedOverrideDiagnostic.uninitializedStoredProperty))
			hasError = true
		}
	}
	return hasError
}

// initializer가 값을 대입해야 하는 저장 프로퍼티 판별
private func typedOverrideRequiresInitialization(_ binding: PatternBindingSyntax) -> Bool {
	guard binding.initializer == nil else {
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

// generated override 이름과 사용자 member의 충돌 진단
func diagnoseTypedOverrideNameCollisions(
	in members: MemberBlockItemListSyntax,
	context: some MacroExpansionContext
) -> Bool {
	let generated = Set(["override", "OverrideBuilder"])
	var hasError = false
	for member in members {
		for name in typedOverrideMemberNames(in: member.decl) where generated.contains(name) {
			context.diagnose(Diagnostic(node: member.decl, message: TypedOverrideDiagnostic.nameCollision(name: name)))
			hasError = true
		}
	}
	return hasError
}

// 이름 충돌 검사에 사용할 직접 member 이름 수집
private func typedOverrideMemberNames(in declaration: DeclSyntax) -> [String] {
	if let function = declaration.as(FunctionDeclSyntax.self) {
		return [function.name.identifier?.name ?? function.name.text]
	}
	if let variable = declaration.as(VariableDeclSyntax.self) {
		return variable.bindings.compactMap { binding in
			binding.pattern.as(IdentifierPatternSyntax.self).map { pattern in
				typedOverrideIdentifierName(pattern.identifier)
			}
		}
	}
	if let structure = declaration.as(StructDeclSyntax.self) {
		return [typedOverrideIdentifierName(structure.name)]
	}
	if let enumeration = declaration.as(EnumDeclSyntax.self) {
		return [typedOverrideIdentifierName(enumeration.name)]
	}
	if let nestedClass = declaration.as(ClassDeclSyntax.self) {
		return [typedOverrideIdentifierName(nestedClass.name)]
	}
	if let nestedActor = declaration.as(ActorDeclSyntax.self) {
		return [typedOverrideIdentifierName(nestedActor.name)]
	}
	if let protocolDeclaration = declaration.as(ProtocolDeclSyntax.self) {
		return [typedOverrideIdentifierName(protocolDeclaration.name)]
	}
	if let alias = declaration.as(TypeAliasDeclSyntax.self) {
		return [typedOverrideIdentifierName(alias.name)]
	}
	return []
}

// Swift backtick 표기를 제외한 선언 이름 반환
private func typedOverrideIdentifierName(_ token: TokenSyntax) -> String {
	token.identifier?.name ?? token.text
}

// Macro context의 고유 이름을 유효한 Swift identifier로 정규화
private func typedOverrideUniqueName(
	_ base: String,
	in context: some MacroExpansionContext
) -> TokenSyntax {
	let unique = context.makeUniqueName(base).trimmedDescription
	let identifier = unique.unicodeScalars.map { scalar in
		if scalar == "_" || scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
			String(scalar)
		} else {
			"_"
		}
	}.joined()
	return .identifier(identifier)
}

// 사용자 저장 프로퍼티 검사에서 제외할 type member 판별
private func typedOverrideHasTypeMemberModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
	}
}

// `DependencyOverride`를 graph 내부 선택 상태로 변환하는 enum 선언
private func selectionDeclaration(for override: TypedOverrideProvider) -> DeclSyntax {
	let sendable = override.requiresSendableFactory ? ": Sendable" : ""
	return DeclSyntax(
		"""
		fileprivate enum \(override.stateName)\(raw: sendable) {
		    case original
		    case factory(\(raw: override.factoryType))

		    init(_ selection: DependencyOverride<\(raw: override.factoryType)>) {
		        switch selection {
		        case .original:
		            self = .original
		        case let .factory(factory):
		            self = .factory(factory)
		        }
		    }
		}
		"""
	)
}

// graph 생성 전 override 상태만 보관하는 nested builder 선언
private func builderDeclaration(
	named builderName: TokenSyntax,
	graph: DependencyGraphDeclaration,
	providers: [TypedOverrideProvider],
	sources: [SourceGraphDescriptor],
	accessLevel: AccessLevel
) -> DeclSyntax {
	let sendable = graph.isActor ? ": Sendable" : ""
	let fields = providers.map { override in
		"fileprivate let \(override.storageName): \(override.stateName)"
	}.joined(separator: "\n")
	let parameters = providers.map { override in
		"\(override.storageName): \(override.stateName)"
	}.joined(separator: ", ")
	let assignments = providers.map { override in
		"self.\(override.storageName) = \(override.storageName)"
	}.joined(separator: "\n")
	let sourceParameters = sources.map { source in
		"\(source.propertyName): \(source.type.trimmedDescription)"
	}.joined(separator: ", ")
	let sourceArguments = sources.map { source in
		"\(source.propertyName): \(source.propertyName)"
	}.joined(separator: ", ")
	let buildParameters = sourceParameters.isEmpty ? "" : sourceParameters
	let buildArguments = (["overrides: self"] + (sourceArguments.isEmpty ? [] : [sourceArguments])).joined(separator: ", ")
	return DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) struct \(builderName)\(raw: sendable) {
		    \(raw: fields)

		    fileprivate init(\(raw: parameters)) {
		        \(raw: assignments)
		    }

		\(raw: accessLevel.rawValue) func build(\(raw: buildParameters)) -> \(graph.name) {
		    \(graph.name)(\(raw: buildArguments))
		    }
		}
		"""
	)
}

// 등록별 default `.original`을 가진 static override 진입점 선언
private func overrideEntryPoint(
	named builderName: TokenSyntax,
	providers: [TypedOverrideProvider],
	accessLevel: AccessLevel
) -> DeclSyntax {
	let parameters = providers.map { override in
		"\(override.provider.propertyName): DependencyOverride<\(override.factoryType)> = .original"
	}.joined(separator: ", ")
	let arguments = providers.map { override in
		"\(override.storageName): \(override.stateName)(\(override.provider.propertyName))"
	}.joined(separator: ", ")
	return DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) static func `override`(\(raw: parameters)) -> \(builderName) {
		    \(builderName)(\(raw: arguments))
		}
		"""
	)
}

// 기본 Graph 생성과 builder 전용 생성 경로 선언
// swiftlint:disable:next function_parameter_count
private func graphInitializers(
	graphName: TokenSyntax,
	builderName: TokenSyntax,
	providers: [TypedOverrideProvider],
	sources: [SourceGraphDescriptor],
	transient: [TypedOverrideProvider],
	storage: TypedOverrideSharedStorage,
	accessLevel: AccessLevel,
	isActor: Bool
) -> [DeclSyntax] {
	let transientAssignments = transient.map { override in
		"self.\(override.storageName) = overrides.\(override.storageName)"
	}.joined(separator: "\n")
	let storageAssignment = storage.initializationAssignment(sources: sources)
	let sourceParameters = sources.map { source in
		"\(source.propertyName): \(source.type.trimmedDescription)"
	}.joined(separator: ", ")
	let sourceArguments = sources.map { source in
		"\(source.propertyName): \(source.propertyName)"
	}.joined(separator: ", ")
	let originalValues = ["overrides: Self.override()"]
		+ (sourceArguments.isEmpty ? [] : [sourceArguments])
	let originalArguments = originalValues.joined(separator: ", ")
	let initializerModifier = isActor ? "" : "convenience "
	let originalInit = DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) \(raw: initializerModifier)init(\(raw: sourceParameters)) {
		    self.init(\(raw: originalArguments))
		}
		"""
	)
	let privateParameters = (["overrides: \(builderName)"] + (sourceParameters.isEmpty ? [] : [sourceParameters])).joined(separator: ", ")
	let sourceAssignments = sources.map { source in
		"self.\(source.propertyName) = \(source.propertyName)"
	}.joined(separator: "\n")
	let overrideInit = DeclSyntax(
		"""
		private init(\(raw: privateParameters)) {
		    \(raw: sourceAssignments)
		    \(raw: transientAssignments)
		    \(raw: storageAssignment)
		}
		"""
	)
	return [originalInit, overrideInit]
}

// shared 저장소 참조와 transient Factory 선택을 반영한 생성 프로퍼티 선언
private func typedOverridePropertyDeclarations(
	providers: [TypedOverrideProvider],
	sources: [SourceGraphDescriptor],
	accessLevel: AccessLevel,
	propertyNames: [RegisteredTypeIdentity: String],
	storage: TypedOverrideSharedStorage
) -> [DeclSyntax] {
	let sourceStorage = sources.map { source in
		DeclSyntax("private let \(raw: source.propertyName): \(raw: source.type.trimmedDescription)")
	}
	let transientStorage = providers.filter { $0.provider.lifetime == .transient }.map { override in
		DeclSyntax("private let \(override.storageName): \(override.stateName)")
	}
	let properties = providers.map { override in
		let provider = override.provider
		let signature = "\(accessLevel.rawValue) var \(provider.propertyName): \(provider.returnType.trimmedDescription)"
		if provider.lifetime == .shared {
			return DeclSyntax("""
			\(raw: signature) {
			    \(raw: storage.valueReference(for: override))
			}
			""")
		}
		let originalArguments = provider.parameters.map { parameter in
			parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity]!)
		}.joined(separator: ", ")
		let overrideArguments = provider.parameters.map { parameter in
			propertyNames[parameter.typeIdentity]!
		}.joined(separator: ", ")
		return DeclSyntax("""
		\(raw: signature) {
		    switch \(override.storageName) {
		    case .original:
		        \(raw: provider.factoryName)(\(raw: originalArguments))
		    case let .factory(factory):
		        factory(\(raw: overrideArguments))
		    }
		}
		""")
	}
	return sourceStorage + transientStorage + storage.declarations() + properties
}

// override-enabled graph의 shared 결과 저장소 생성
private struct TypedOverrideSharedStorage {
	// shared 결과 저장 타입 이름
	let typeName: TokenSyntax?
	// graph 저장 프로퍼티 이름
	let propertyName: TokenSyntax?
	// shared 결과 생성 함수 이름
	let builderName: TokenSyntax?
	// graph 이름
	let graphName: TokenSyntax
	// outer builder 이름
	let overrideBuilderName: TokenSyntax
	// shared 등록
	let providers: [TypedOverrideProvider]
	// 조합 graph가 소유하는 source graph
	let sources: [SourceGraphDescriptor]
	// 등록 의존성 연결
	let propertyNames: [RegisteredTypeIdentity: String]
	// 원본 shared Factory helper 이름
	let helperNames: [RegisteredTypeIdentity: TokenSyntax]
	// shared Factory의 source 참조 위치
	let sourceReferences: [RegisteredTypeIdentity: SourceGraphReferences]
	// shared Factory별 실제 source graph
	let providerSources: [RegisteredTypeIdentity: [SourceGraphDescriptor]]
	// helper source 매개변수 이름
	let helperSourceNames: [RegisteredTypeIdentity: [RegisteredTypeIdentity: TokenSyntax]]

	init(
		graphName: TokenSyntax,
		builderName: TokenSyntax,
		providers: [TypedOverrideProvider],
		sources: [SourceGraphDescriptor],
		propertyNames: [RegisteredTypeIdentity: String],
		in context: some MacroExpansionContext
	) {
		self.graphName = graphName
		overrideBuilderName = builderName
		self.providers = providers
		self.sources = sources
		self.propertyNames = propertyNames
		guard !providers.isEmpty else {
			typeName = nil
			propertyName = nil
			self.builderName = nil
			helperNames = [:]
			sourceReferences = [:]
			providerSources = [:]
			helperSourceNames = [:]
			return
		}
		typeName = typedOverrideUniqueName("TypedOverrideSharedStorage", in: context)
		propertyName = typedOverrideUniqueName("typedOverrideSharedStorage", in: context)
		self.builderName = typedOverrideUniqueName("makeTypedOverrideSharedStorage", in: context)
		helperNames = Dictionary(uniqueKeysWithValues: providers.map { override in
			(override.provider.registrationIdentity, typedOverrideUniqueName("makeTypedOverrideShared", in: context))
		})
		let sourceNames = Set(sources.map(\.propertyIdentifier))
		let references = Dictionary(uniqueKeysWithValues: providers.map { override in
			let sourceReferences = sourceGraphReferences(
				in: override.provider.factory,
				sourceNames: sourceNames
			)
			return (override.provider.registrationIdentity, sourceReferences)
		})
		sourceReferences = references
		let selectedSources = Dictionary(uniqueKeysWithValues: providers.map { override in
			let names = references[override.provider.registrationIdentity]?.sourceNames ?? []
			return (override.provider.registrationIdentity, sources.filter { names.contains($0.propertyIdentifier) })
		})
		providerSources = selectedSources
		let names = Dictionary(uniqueKeysWithValues: providers.map { override in
				let selected = selectedSources[override.provider.registrationIdentity] ?? []
				let values = Dictionary(uniqueKeysWithValues: selected.map { source in
				(source.identity, typedOverrideUniqueName("source", in: context))
			})
			return (override.provider.registrationIdentity, values)
		})
		helperSourceNames = names
	}

	// shared 저장소 선언과 helper 선언 생성
	func declarations() -> [DeclSyntax] {
		guard let typeName, let builderName else {
			return []
		}
		let fields = providers.map { override in
			"let \(override.provider.propertyName): \(override.provider.returnType.trimmedDescription)"
		}.joined(separator: "\n")
		let storage = DeclSyntax("""
		private struct \(typeName) {
		    \(raw: fields)
		}
		""")
		let helpers = providers.compactMap { helperDeclaration(for: $0) }
		let ordered = sharedDependencyOrder(in: providers.map(\.provider))
		let orderedOverrides = ordered.compactMap { provider in
			providers.first { $0.provider.registrationIdentity == provider.registrationIdentity }
		}
		let constructions = orderedOverrides.map(construction).joined(separator: "\n")
		let arguments = providers.map { override in
			"\(override.provider.propertyName): \(override.provider.propertyName)"
		}.joined(separator: ", ")
		let sourceParameters = builderSources.map { source in
			"\(source.propertyName): \(source.type.trimmedDescription)"
		}.joined(separator: ", ")
		let parameters = (["_ overrides: \(overrideBuilderName)"] + (sourceParameters.isEmpty ? [] : [sourceParameters])).joined(separator: ", ")
		let builder = DeclSyntax("""
		private static func \(builderName)(\(raw: parameters)) -> \(typeName) {
		    \(raw: constructions)
		    return \(typeName)(\(raw: arguments))
		}
		""")
		let property = DeclSyntax("private let \(propertyName): \(typeName)")
		return [storage] + helpers + [builder, property]
	}

	// graph initializer가 실행할 shared 저장소 대입문
	func initializationAssignment(sources: [SourceGraphDescriptor]) -> String {
		guard let propertyName, let builderName else {
			return ""
		}
		let arguments = builderSources.map { source in
			"\(source.propertyName): \(source.propertyName)"
		}.joined(separator: ", ")
		let supplied = (["overrides"] + (arguments.isEmpty ? [] : [arguments])).joined(separator: ", ")
		return "self.\(propertyName) = Self.\(builderName)(\(supplied))"
	}

	// shared 생성 프로퍼티의 저장소 값 참조
	func valueReference(for override: TypedOverrideProvider) -> String {
		guard let propertyName else {
			return ""
		}
		return "\(propertyName).\(override.provider.propertyName)"
	}

	// 원본 shared Factory helper 선언
	private func helperDeclaration(for override: TypedOverrideProvider) -> DeclSyntax? {
		guard let name = helperNames[override.provider.registrationIdentity],
			let body = sharedHelperBody(
				for: override.provider.factory,
				references: sourceReferences[override.provider.registrationIdentity],
				sourceParameterNames: sourceParameterNames(for: override)
			) else {
			return nil
		}
		let parameters = override.provider.factory.signature.parameterClause.parameters.map { parameter in
			parameter.with(\.trailingComma, nil).trimmedDescription
		} + helperSources(for: override).compactMap { source in
			guard let name = helperSourceNames[override.provider.registrationIdentity]?[source.identity] else {
				return nil
			}
			return "\(name): \(source.type.trimmedDescription)"
		}
		return DeclSyntax("""
		private static func \(name)(\(raw: parameters.joined(separator: ", "))) -> \(raw: override.provider.returnType.trimmedDescription) \(raw: body)
		""")
	}

	// 원본 또는 교체 Factory를 선택한 shared 지역 값 생성
	private func construction(for override: TypedOverrideProvider) -> String {
		let originalArguments = override.provider.parameters.map { parameter in
			parameter.factoryArgument(propertyName: propertyNames[parameter.typeIdentity]!)
		}.joined(separator: ", ")
		let overrideArguments = override.provider.parameters.map { parameter in
			propertyNames[parameter.typeIdentity]!
		}.joined(separator: ", ")
		let sourceArguments = helperSources(for: override).compactMap { source -> String? in
			guard let name = helperSourceNames[override.provider.registrationIdentity]?[source.identity] else {
				return nil
			}
			return "\(name): \(source.propertyName)"
		}.joined(separator: ", ")
		let originalCallArguments = ([originalArguments] + (sourceArguments.isEmpty ? [] : [sourceArguments]))
			.filter { !$0.isEmpty }
			.joined(separator: ", ")
		let helper = helperNames[override.provider.registrationIdentity]!.trimmedDescription
		return """
		let \(override.provider.propertyName): \(override.provider.returnType.trimmedDescription)
		\t= switch overrides.\(override.storageName) {
		\tcase .original:
		\t\t\(helper)(\(originalCallArguments))
		\tcase let .factory(factory):
		\t\tfactory(\(overrideArguments))
		\t}
		"""
	}

	// shared builder가 전달해야 하는 source graph
	private var builderSources: [SourceGraphDescriptor] {
		sources.filter { source in
			helperSourceNames.values.contains { names in
				names[source.identity] != nil
			}
		}
	}

	// 한 shared Factory가 읽는 source graph
	private func helperSources(for override: TypedOverrideProvider) -> [SourceGraphDescriptor] {
		providerSources[override.provider.registrationIdentity] ?? []
	}

	// source 이름을 helper 매개변수 이름으로 연결
	private func sourceParameterNames(for override: TypedOverrideProvider) -> [String: String] {
		Dictionary(uniqueKeysWithValues: helperSources(for: override).compactMap { source in
			guard let name = helperSourceNames[override.provider.registrationIdentity]?[source.identity] else {
				return nil
			}
			return (source.propertyIdentifier, name.trimmedDescription)
		})
	}
}
