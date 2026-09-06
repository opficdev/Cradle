//
//  SharedGraphDeclaration.swift
//  CradleMacros
//
//  Created by opfic on 9/6/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// source graph 조합을 포함한 정적 접근점 선언 생성
func sharedGraphDeclaration(
	for graph: DependencyGraphDeclaration,
	sources: [SourceGraphDescriptor],
	accessLevel: AccessLevel,
	in context: some MacroExpansionContext
) -> DeclSyntax {
	let graphName = graph.name.trimmedDescription
	guard !sources.isEmpty else {
		return DeclSyntax(
			"""
			\(raw: accessLevel.rawValue) static let shared: \(raw: graphName) = \(raw: graphName)()
			"""
		)
	}
	let sourceAliases = Dictionary(uniqueKeysWithValues: sources.map { source in
		(source.identity, context.makeUniqueName("shared\(source.propertyIdentifier)Type"))
	})
	let sourceNames = Dictionary(uniqueKeysWithValues: sources.map { source in
		(source.identity, context.makeUniqueName("shared\(source.propertyIdentifier)"))
	})
	let sourceInitializations = sources.map { source in
		let alias = sourceAliases[source.identity]!.trimmedDescription
		let name = sourceNames[source.identity]!.trimmedDescription
		return "typealias \(alias) = \(source.type.trimmedDescription)\nlet \(name): \(alias) = \(alias).shared"
	}.joined(separator: "\n")
	let arguments = sources.map { source in
		let name = sourceNames[source.identity]!.trimmedDescription
		return "\(source.propertyName): \(name)"
	}.joined(separator: ", ")
	return DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) static let shared: \(raw: graphName) = {
		    \(raw: sourceInitializations)
		    return \(raw: graphName)(\(raw: arguments))
		}()
		"""
	)
}

// `.shared` 정적 접근점의 lifetime·동시성·이름 충돌 검증
func validatedSharedGraphLifetime(
	for graph: DependencyGraphDeclaration,
	attribute: AttributeSyntax,
	context: some MacroExpansionContext
) -> DependencyGraphLifetimeConfiguration? {
	guard let lifetime = dependencyGraphLifetimeConfiguration(from: attribute, in: context) else {
		return nil
	}
	guard lifetime.createsSharedGraph else {
		return lifetime
	}
	guard let lifetimeArgument = dependencyGraphLifetimeArgument(in: attribute) else {
		return nil
	}
	if !graph.isActor, !graph.isMainActor {
		if graph.hasUncheckedSendable {
			context.diagnose(
				Diagnostic(node: lifetimeArgument, message: DependencyGraphLifetimeDiagnostic.uncheckedSharedGraph)
			)
			return nil
		}
		guard graph.isCheckedSendable else {
			context.diagnose(
				Diagnostic(node: lifetimeArgument, message: DependencyGraphLifetimeDiagnostic.sharedGraphRequiresSendable)
			)
			return nil
		}
	}
	guard !typeMemberNames(in: graph.memberBlock.members).contains("shared") else {
		context.diagnose(
			Diagnostic(node: lifetimeArgument, message: DependencyGraphLifetimeDiagnostic.sharedMemberCollision)
		)
		return nil
	}
	return lifetime
}

// graph 직접 type member 이름 수집
private func typeMemberNames(in members: MemberBlockItemListSyntax) -> Set<String> {
	members.reduce(into: Set<String>()) { names, member in
		if let function = member.decl.as(FunctionDeclSyntax.self),
			hasTypeMemberModifier(in: function.modifiers) {
			names.insert(typeMemberName(function.name))
			return
		}

		if let variable = member.decl.as(VariableDeclSyntax.self),
			hasTypeMemberModifier(in: variable.modifiers) {
			for binding in variable.bindings {
				guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
					continue
				}
				names.insert(typeMemberName(pattern.identifier))
			}
		}
	}
}

// backtick을 제외한 type member 비교용 이름 반환
private func typeMemberName(_ token: TokenSyntax) -> String {
	token.identifier?.name ?? token.text
}

// static·class type member 여부 확인
private func hasTypeMemberModifier(in modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static)
			|| modifier.name.tokenKind == .keyword(.class)
	}
}
