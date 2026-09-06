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

// source·override 없는 graph의 정적 접근점 선언 생성
func sharedGraphDeclaration(
	for graph: DependencyGraphDeclaration,
	accessLevel: AccessLevel
) -> DeclSyntax {
	let graphName = graph.name.trimmedDescription
	return DeclSyntax(
		"""
		\(raw: accessLevel.rawValue) static let shared: \(raw: graphName) = \(raw: graphName)()
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
			names.insert(function.name.text)
			return
		}

		if let variable = member.decl.as(VariableDeclSyntax.self),
			hasTypeMemberModifier(in: variable.modifiers) {
			for binding in variable.bindings {
				guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
					continue
				}
				names.insert(pattern.identifier.text)
			}
		}
	}
}

// static·class type member 여부 확인
private func hasTypeMemberModifier(in modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static)
			|| modifier.name.tokenKind == .keyword(.class)
	}
}
