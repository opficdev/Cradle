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
		for binding in node.bindings {
			insert(sourceGraphBoundNames(in: binding.pattern))
		}
	}

	// closure capture·매개변수 shadowing scope 추가
	override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
		if let capture = node.signature?.capture {
			walkSourceGraphCapture(capture)
		}
		let names = sourceGraphClosureCaptureNames(in: node)
			.union(sourceGraphClosureParameterNames(in: node))
		scopes.append(names)
		walk(node.statements)
		scopes.removeLast()
		return .skipChildren
	}

	// if 조건 binding의 initializer와 본문 scope 분리 탐색
	override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
		scopes.append([])
		for element in node.conditions {
			walkSourceGraphCondition(element.condition)
			insert(sourceGraphBoundNames(in: element.condition))
		}
		walk(node.body)
		scopes.removeLast()
		if let elseBody = node.elseBody {
			walk(elseBody)
		}
		return .skipChildren
	}

	// while 조건 binding의 initializer와 본문 scope 분리 탐색
	override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
		scopes.append([])
		for element in node.conditions {
			walkSourceGraphCondition(element.condition)
			insert(sourceGraphBoundNames(in: element.condition))
		}
		walk(node.body)
		scopes.removeLast()
		return .skipChildren
	}

	// guard 조건 binding을 뒤따르는 같은 code block에 추가
	override func visitPost(_ node: GuardStmtSyntax) {
		for element in node.conditions {
			insert(sourceGraphBoundNames(in: element.condition))
		}
	}

	// for pattern binding을 sequence 다음 body와 where clause에만 적용
	override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
		walk(node.sequence)
		scopes.append(sourceGraphBoundNames(in: node.pattern))
		if let whereClause = node.whereClause {
			walk(whereClause)
		}
		walk(node.body)
		scopes.removeLast()
		return .skipChildren
	}

	// catch pattern binding을 where clause와 catch 본문에만 적용
	override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
		scopes.append(sourceGraphCatchClauseNames(in: node))
		walk(node.catchItems)
		walk(node.body)
		scopes.removeLast()
		return .skipChildren
	}

	// 중첩 함수 매개변수 scope와 선언 이름 적용
	override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
		for parameter in node.signature.parameterClause.parameters {
			if let defaultValue = parameter.defaultValue {
				walk(defaultValue.value)
			}
		}
		let names = sourceGraphFunctionParameterNames(in: node)
			.union([sourceGraphIdentifierName(node.name)])
		scopes.append(names)
		if let body = node.body {
			walk(body)
		}
		scopes.removeLast()
		insert([sourceGraphIdentifierName(node.name)])
		return .skipChildren
	}

	// switch case pattern binding을 where clause와 case 본문에만 적용
	override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
		scopes.append(sourceGraphSwitchCaseNames(in: node))
		walk(node.label)
		walk(node.statements)
		scopes.removeLast()
		return .skipChildren
	}

	// shadowing되지 않은 source 저장 프로퍼티의 첫 참조 기록
	override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
		recordSourceGraphReference(node.baseName)
		return .skipChildren
	}

	// 명시적 self의 source 저장 프로퍼티 참조 기록
	override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
		guard let base = node.base?.as(DeclReferenceExprSyntax.self),
			base.baseName.tokenKind == .keyword(.self) else {
			return .visitChildren
		}
		recordSourceGraphReference(node.declName.baseName, ignoresShadowing: true)
		return .skipChildren
	}

	// 현재 가장 안쪽 scope에 새 binding 이름 추가
	private func insert(_ names: Set<String>) {
		guard var scope = scopes.popLast() else {
			return
		}
		scope.formUnion(names)
		scopes.append(scope)
	}

	// if 조건별 initializer를 먼저 읽는 탐색
	private func walkSourceGraphCondition(_ condition: ConditionElementSyntax.Condition) {
		switch condition {
		case let .expression(expression):
			walk(expression)
		case let .availability(availability):
			walk(availability)
		case let .matchingPattern(matching):
			walk(matching)
		case let .optionalBinding(binding):
			walk(binding)
		}
	}

	// closure capture 초기화식과 bare capture source 참조 탐색
	private func walkSourceGraphCapture(_ capture: ClosureCaptureClauseSyntax) {
		for item in capture.items {
			if let initializer = item.initializer {
				walk(initializer)
			} else {
				recordSourceGraphReference(item.name)
			}
		}
	}

	// shadowing되지 않은 source 저장 프로퍼티 참조 기록
	private func recordSourceGraphReference(
		_ token: TokenSyntax,
		ignoresShadowing: Bool = false
	) {
		guard reference == nil else {
			return
		}
		let name = sourceGraphIdentifierName(token)
		guard sourceNames.contains(name) else {
			return
		}
		guard ignoresShadowing || !scopes.contains(where: { $0.contains(name) }) else {
			return
		}
		reference = token
	}
}

// pattern에서 선언하는 이름 수집기
private final class SourceGraphPatternNameFinder: SyntaxVisitor {
	// pattern이 선언하는 지역 이름 집합
	private(set) var names = Set<String>()

	// identifier pattern의 선언 이름 수집
	override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
		names.insert(sourceGraphIdentifierName(node.identifier))
		return .skipChildren
	}
}

// pattern의 모든 지역 binding 이름 수집
private func sourceGraphBoundNames(in pattern: PatternSyntax) -> Set<String> {
	let finder = SourceGraphPatternNameFinder(viewMode: .sourceAccurate)
	finder.walk(pattern)
	return finder.names
}

// 조건 binding이 선언하는 이름 수집
private func sourceGraphBoundNames(in condition: ConditionElementSyntax.Condition) -> Set<String> {
	switch condition {
	case let .matchingPattern(matching):
		sourceGraphBoundNames(in: matching.pattern)
	case let .optionalBinding(binding):
		sourceGraphBoundNames(in: binding.pattern)
	case .expression, .availability:
		[]
	}
}

// closure 매개변수의 지역 이름 수집
private func sourceGraphClosureParameterNames(in closure: ClosureExprSyntax) -> Set<String> {
	guard let parameterClause = closure.signature?.parameterClause else {
		return []
	}
	switch parameterClause {
	case let .simpleInput(parameters):
		return Set(parameters.map { sourceGraphIdentifierName($0.name) })
	case let .parameterClause(parameters):
		return Set(parameters.parameters.map { parameter in
			sourceGraphIdentifierName(parameter.secondName ?? parameter.firstName)
		})
	}
}

// closure capture가 closure 본문에 선언하는 이름 수집
private func sourceGraphClosureCaptureNames(in closure: ClosureExprSyntax) -> Set<String> {
	guard let capture = closure.signature?.capture else {
		return []
	}
	return Set(capture.items.map { sourceGraphIdentifierName($0.name) })
}

// switch case가 선언하는 지역 이름 수집
private func sourceGraphSwitchCaseNames(in switchCase: SwitchCaseSyntax) -> Set<String> {
	guard case let .case(label) = switchCase.label else {
		return []
	}
	return label.caseItems.reduce(into: Set<String>()) { names, item in
		names.formUnion(sourceGraphBoundNames(in: item.pattern))
	}
}

// catch clause가 선언하는 지역 이름 수집
private func sourceGraphCatchClauseNames(in clause: CatchClauseSyntax) -> Set<String> {
	clause.catchItems.reduce(into: Set<String>()) { names, item in
		guard let pattern = item.pattern else {
			return
		}
		names.formUnion(sourceGraphBoundNames(in: pattern))
	}
}

// 중첩 함수 매개변수의 지역 이름 수집
private func sourceGraphFunctionParameterNames(in function: FunctionDeclSyntax) -> Set<String> {
	Set(function.signature.parameterClause.parameters.map { parameter in
		let name = parameter.secondName ?? parameter.firstName
		return sourceGraphIdentifierName(name)
	})
}

// backtick 표기를 제외한 identifier 이름 읽기
private func sourceGraphIdentifierName(_ token: TokenSyntax) -> String {
	token.identifier?.name ?? token.text
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
