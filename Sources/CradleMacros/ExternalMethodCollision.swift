//
//  ExternalMethodCollision.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// 외부 입력 생성 메서드와 같은 이름의 graph 멤버 진단
func diagnoseExternalMethodNameCollisions(
	in providers: [ProviderDescriptor],
	sources: [SourceGraphDescriptor],
	members: MemberBlockItemListSyntax,
	context: some MacroExpansionContext
) -> Bool {
	let externalProviders = providers.filter(\.hasExternalParameters)
	let instanceMembers = externalCollisionMembers(in: members)
	var reportedNames = Set<String>()
	var hasError = false

	for provider in externalProviders where reportedNames.insert(provider.propertyIdentifier).inserted {
		let providerConflicts = providers.filter { candidate in
			candidate.factory.id != provider.factory.id
				&& candidate.propertyIdentifier == provider.propertyIdentifier
		}
		let sourceConflicts = sources.filter { source in
			source.propertyIdentifier == provider.propertyIdentifier
		}
		let memberConflicts = instanceMembers.filter { member in
			member.name == provider.propertyIdentifier
		}
		let notes = providerConflictNotes(providerConflicts, name: provider.propertyIdentifier)
			+ sourceConflictNotes(sourceConflicts, name: provider.propertyIdentifier)
			+ memberConflictNotes(memberConflicts, name: provider.propertyIdentifier)
		guard !notes.isEmpty else {
			continue
		}
		context.diagnose(
			Diagnostic(
				node: provider.returnType,
				message: ExternalMethodNameCollisionDiagnostic(name: provider.propertyIdentifier),
				notes: notes
			)
		)
		hasError = true
	}
	return hasError
}

// 이름 충돌 검사에 사용할 사용자 인스턴스 멤버
private struct ExternalCollisionMember {
	// 비교할 멤버 이름
	let name: String
	// 보조 설명이 가리킬 원본 선언
	let declaration: DeclSyntax
}

// 모든 인스턴스 프로퍼티와 메서드 이름 수집
private func externalCollisionMembers(
	in members: MemberBlockItemListSyntax
) -> [ExternalCollisionMember] {
	members.flatMap { member -> [ExternalCollisionMember] in
		if let function = member.decl.as(FunctionDeclSyntax.self),
			!externalCollisionHasTypeMemberModifier(function.modifiers) {
			return [
				ExternalCollisionMember(
					name: externalCollisionIdentifier(function.name),
					declaration: member.decl
				)
			]
		}
		guard let variable = member.decl.as(VariableDeclSyntax.self),
			!externalCollisionHasTypeMemberModifier(variable.modifiers) else {
			return []
		}
		return variable.bindings.compactMap { binding in
			guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
				return nil
			}
			return ExternalCollisionMember(
				name: externalCollisionIdentifier(pattern.identifier),
				declaration: member.decl
			)
		}
	}
}

// 백틱 표기와 무관한 인스턴스 멤버 비교 이름
private func externalCollisionIdentifier(_ token: TokenSyntax) -> String {
	token.identifier?.name ?? token.text
}

// 타입 멤버 modifier 포함 여부 확인
private func externalCollisionHasTypeMemberModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
	modifiers.contains { modifier in
		modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.class)
	}
}

// 같은 생성 이름을 만드는 provider 보조 설명
private func providerConflictNotes(
	_ providers: [ProviderDescriptor],
	name: String
) -> [Note] {
	providers.map { provider in
		Note(
			node: Syntax(provider.attribute),
			message: ExternalMethodNameCollisionMemberNote(
				member: "\(quotedFactoryName(provider.factoryName)) Factory가 `\(name)` 생성 멤버를 만듭니다."
			)
		)
	}
}

// 같은 이름의 source 저장 프로퍼티 보조 설명
private func sourceConflictNotes(
	_ sources: [SourceGraphDescriptor],
	name: String
) -> [Note] {
	sources.map { source in
		Note(
			node: Syntax(source.expression),
			message: ExternalMethodNameCollisionMemberNote(
				member: "`\(source.type.trimmedDescription)` source graph가 `\(name)` 저장 프로퍼티를 만듭니다."
			)
		)
	}
}

// 같은 이름의 사용자 인스턴스 멤버 보조 설명
private func memberConflictNotes(
	_ members: [ExternalCollisionMember],
	name: String
) -> [Note] {
	members.map { member in
		Note(
			node: Syntax(member.declaration),
			message: ExternalMethodNameCollisionMemberNote(
				member: "`\(name)` 인스턴스 멤버가 같은 이름을 사용합니다."
			)
		)
	}
}
