//
//  SourceGraphReference.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// shared Factory 본문에서 source 저장 프로퍼티 참조 위치 탐색
func sourceGraphReference(
	in factory: FunctionDeclSyntax,
	sourceNames: Set<String>
) -> TokenSyntax? {
	guard let body = factory.body else {
		return nil
	}
	let finder = SourceGraphReferenceFinder(
		sourceNames: sourceNames,
		parameterNames: Set(factory.signature.parameterClause.parameters.map { parameter in
			let name = parameter.secondName ?? parameter.firstName
			return name.identifier?.name ?? name.text
		})
	)
	finder.walk(body)
	return finder.reference
}

// lexical scope를 반영한 source 저장 프로퍼티 참조 탐색기
private final class SourceGraphReferenceFinder: SyntaxVisitor {
	// 생성된 source 저장 프로퍼티 이름 집합
	private let sourceNames: Set<String>
	// 현재 lexical scope의 shadowing 이름 집합
	private var scopes: [Set<String>]
	// 처음 찾은 source 저장 프로퍼티 참조
	private(set) var reference: TokenSyntax?

	// source 이름과 Factory 매개변수 이름으로 탐색기 생성
	init(sourceNames: Set<String>, parameterNames: Set<String>) {
		self.sourceNames = sourceNames
		scopes = [parameterNames]
		super.init(viewMode: .sourceAccurate)
	}

	// code block마다 지역 변수 shadowing scope 추가
	override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
		scopes.append([])
		return .visitChildren
	}

	// code block 종료 후 지역 변수 shadowing scope 제거
	override func visitPost(_ node: CodeBlockSyntax) {
		scopes.removeLast()
	}

	// initializer를 읽은 뒤 선언한 지역 변수 이름을 현재 scope에 추가
	override func visitPost(_ node: VariableDeclSyntax) {
		guard var scope = scopes.popLast() else {
			return
		}
		for binding in node.bindings {
			guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
				continue
			}
			scope.insert(pattern.identifier.identifier?.name ?? pattern.identifier.text)
		}
		scopes.append(scope)
	}

	// shadowing되지 않은 source 저장 프로퍼티의 첫 참조 기록
	override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
		guard reference == nil else {
			return .skipChildren
		}
		let name = node.baseName.identifier?.name ?? node.baseName.text
		guard sourceNames.contains(name),
			!scopes.contains(where: { $0.contains(name) }) else {
			return .skipChildren
		}
		reference = node.baseName
		return .skipChildren
	}
}

// shared Factory의 source 저장 프로퍼티 참조 진단
func diagnoseSourceGraphSharedReferenceErrors(
	in providers: [ProviderDescriptor],
	sources: [SourceGraphDescriptor],
	context: some MacroExpansionContext
) -> Bool {
	let sourceNames = Set(sources.map(\.propertyIdentifier))
	guard !sourceNames.isEmpty else {
		return false
	}
	var hasError = false
	for provider in providers where provider.lifetime == .shared {
		guard let reference = sourceGraphReference(in: provider.factory, sourceNames: sourceNames) else {
			continue
		}
		let name = reference.identifier?.name ?? reference.text
		context.diagnose(
			Diagnostic(
				node: reference,
				message: SourceGraphDiagnostic.sharedSourceReference(name: name)
			)
		)
		hasError = true
	}
	return hasError
}
