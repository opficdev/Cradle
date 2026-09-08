//
//  WorkspaceCompositionSupport.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

import SwiftSyntax

// 조립 expression을 해석하는 source와 lexical 소유 경로
struct WorkspaceCompositionEvaluationContext {
	// expression이 작성된 source 문맥
	let source: WorkspaceSourceContext
	// 현재 소유 type의 lexical 경로
	let lexicalPath: [String]
}

// graph input 참조 수집 결과
struct WorkspaceInputReferenceCollection {
	// 직접 읽은 input 저장 멤버
	let members: Set<String>
	// 지원하지 않는 input 사용 위치
	let unsupported: [WorkspaceUnsupportedInputReference]
}

// 지원하지 않는 input 사용의 진단 정보
struct WorkspaceUnsupportedInputReference {
	// 진단 종류
	let code: WorkspaceDiagnosticCode
	// source UTF-8 위치
	let utf8Offset: Int
}

// composition graph instance
struct WorkspaceCompositionGraph {
	// graph instance key
	let key: String
	// 원본 graph 선언
	let descriptor: WorkspaceGraphDescriptor
	// graph initializer input 값
	let inputs: [String: WorkspaceCompositionValue]
	// graph initializer source 값
	let sources: [String: WorkspaceCompositionValue]

	// instance별 provider
	var providers: [WorkspaceCompositionProvider] {
		descriptor.diagram.providers.sorted { $0.factoryName < $1.factoryName }.enumerated().map { offset, provider in
			WorkspaceCompositionProvider(graph: self, descriptor: provider, offset: offset)
		}
	}
}

// graph instance의 provider 결과 경로
struct WorkspaceCompositionProvider {
	// provider가 속한 graph instance
	let graph: WorkspaceCompositionGraph
	// 원본 provider 선언
	let descriptor: GraphDiagramProvider
	// 같은 graph 안의 결정적 provider 순서
	let offset: Int

	// Mermaid provider node key
	var key: String {
		"\(graph.key)/provider/\(descriptor.factoryName)/\(offset)"
	}
}

// 일반 조립 객체의 인스턴스별 저장 멤버 값
final class WorkspaceCompositionObject {
	// object instance key
	let key: String
	// 원본 type 선언
	let declaration: WorkspaceTypeDeclaration
	// 해석한 stored let 값
	var members = [String: WorkspaceCompositionValue]()

	init(key: String, declaration: WorkspaceTypeDeclaration) {
		self.key = key
		self.declaration = declaration
	}
}

// 조립 값의 실제 provider·graph·object 출처
indirect enum WorkspaceCompositionValue {
	// graph instance
	case graph(WorkspaceCompositionGraph)
	// 일반 조립 객체
	case object(WorkspaceCompositionObject)
	// provider 결과
	case provider(WorkspaceCompositionProvider, accessKey: String?)
	// input 생성자 label별 값
	case input([String: WorkspaceCompositionValue])
	// 출처를 해석하지 못한 값
	case unknown(String)
}

// composition edge 중복 key
struct WorkspaceCompositionEdgeKey: Hashable {
	// 시작 node key
	let from: String
	// 끝 node key
	let destination: String
	// 관계 종류
	let kind: WorkspaceDiagramEdgeKind
}

// initializer 호출 인자의 label·값
struct WorkspaceCompositionCallArgument {
	// 외부 인자 label
	let label: String?
	// 호출자 환경에서 평가한 값
	let value: WorkspaceCompositionValue
}

// self 저장 멤버 대입의 멤버 이름과 우변 expression
struct WorkspaceStoredLetAssignment {
	// 대입할 저장 멤버 이름
	let member: String
	// 대입 우변 expression
	let expression: ExprSyntax
}

// 직접 let 저장 멤버 이름을 선언 순서대로 반환
func workspaceDirectStoredLetMemberNames(
	in memberBlock: MemberBlockSyntax
) -> [String] {
	memberBlock.members.compactMap { member in
		guard let variable = member.decl.as(VariableDeclSyntax.self),
			variable.bindingSpecifier.tokenKind == .keyword(.let),
			variable.attributes.isEmpty,
			!variable.modifiers.contains(where: { modifier in
				["lazy", "static", "class"].contains(modifier.name.text)
			}),
			variable.bindings.count == 1,
			let binding = variable.bindings.first,
			binding.accessorBlock == nil,
			let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
			return nil
		}
		return identifier.identifier.text
	}
}

// 명시 initializer와 기본값이 없는 직접 let만 memberwise initializer 합성 허용
func workspaceCanSynthesizeMemberwiseInitializer(
	in memberBlock: MemberBlockSyntax
) -> Bool {
	guard !workspaceDirectStoredLetMemberNames(in: memberBlock).isEmpty,
		!memberBlock.members.contains(where: { $0.decl.is(InitializerDeclSyntax.self) }) else {
		return false
	}
	return memberBlock.members.allSatisfy { member in
		guard let variable = member.decl.as(VariableDeclSyntax.self) else {
			return true
		}
		return variable.bindings.allSatisfy { $0.initializer == nil }
	}
}

// 인자 label과 개수가 정확히 일치하는 initializer 후보 반환
func workspaceInitializers(
	in memberBlock: MemberBlockSyntax,
	labels: [String?]
) -> [InitializerDeclSyntax] {
	memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }.filter { initializer in
		initializer.signature.parameterClause.parameters.map { $0.firstName.text } == labels.map { $0 ?? "_" }
	}
}

// self 직접 저장 멤버에 대한 단순 assignment 변환
func workspaceStoredLetAssignment(
	from expression: ExprSyntax,
	memberNames: Set<String>
) -> WorkspaceStoredLetAssignment? {
	guard let sequence = expression.as(SequenceExprSyntax.self) else {
		return nil
	}
	let elements = Array(sequence.elements)
	guard elements.count == 3,
		let member = elements[0].as(MemberAccessExprSyntax.self),
		elements[1].as(AssignmentExprSyntax.self) != nil,
		let base = member.base?.as(DeclReferenceExprSyntax.self),
		base.baseName.tokenKind == .keyword(.self),
		memberNames.contains(member.declName.baseName.text) else {
		return nil
	}
	return WorkspaceStoredLetAssignment(member: member.declName.baseName.text, expression: elements[2])
}

// provider 이름에 대응하는 직접 member function 반환
func workspaceProviderFunction(
	named name: String,
	in memberBlock: MemberBlockSyntax
) -> FunctionDeclSyntax? {
	memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }.first {
		$0.name.text == name
	}
}

// input 또는 self.input의 직접 member access 수집기
final class WorkspaceInputMemberReferenceCollector: SyntaxVisitor {
	// graph input의 실제 저장 멤버
	private let memberNames: Set<String>
	// bare input 가림을 확인할 lexical scope
	private var scopes: [Set<String>]
	// 읽은 input 저장 멤버
	private(set) var members = Set<String>()
	// 지원하지 않는 input 사용 위치
	private(set) var unsupported = [WorkspaceUnsupportedInputReference]()

	init(memberNames: Set<String>, parameterNames: Set<String>) {
		self.memberNames = memberNames
		scopes = [parameterNames]
		super.init(viewMode: .sourceAccurate)
	}

	// 함수 본문과 중첩 block의 지역 이름을 분리
	override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
		scopes.append([])
		return .visitChildren
	}

	override func visitPost(_ node: CodeBlockSyntax) {
		scopes.removeLast()
	}

	// let·var 선언의 초기화식은 가림 전에 읽고 이후 이름을 가림 처리
	override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
		for binding in node.bindings {
			if let initializer = binding.initializer {
				walk(initializer.value)
			}
			if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
				insert(identifier.identifier.text)
			}
		}
		return .skipChildren
	}

	// closure·중첩 선언·제어 흐름 내부는 첫 버전에서 input read로 단정하지 않음
	override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
		recordUnsupportedInputUse(in: node, code: .unsupportedExpression)
		return .skipChildren
	}
	override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
	override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
		recordUnsupportedInputUse(in: node, code: .unsupportedControlFlow)
		return .skipChildren
	}
	override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
		recordUnsupportedInputUse(in: node, code: .unsupportedControlFlow)
		return .skipChildren
	}
	override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
		recordUnsupportedInputUse(in: node, code: .unsupportedControlFlow)
		return .skipChildren
	}
	override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
		recordUnsupportedInputUse(in: node, code: .unsupportedControlFlow)
		return .skipChildren
	}

	// 특정 멤버를 읽지 않는 bare input 전달은 별도 경고로 기록
	override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
		guard node.baseName.text == "input", !isShadowed("input") else {
			return .skipChildren
		}
		unsupported.append(WorkspaceUnsupportedInputReference(
			code: .opaqueInputUse,
			utf8Offset: node.positionAfterSkippingLeadingTrivia.utf8Offset
		))
		return .skipChildren
	}

	override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
		if let base = node.base?.as(DeclReferenceExprSyntax.self),
			base.baseName.text == "input",
			!isShadowed("input") {
			record(node.declName.baseName.text)
		} else if let base = node.base?.as(MemberAccessExprSyntax.self),
			let selfBase = base.base?.as(DeclReferenceExprSyntax.self),
			selfBase.baseName.tokenKind == .keyword(.self),
			base.declName.baseName.text == "input" {
			record(node.declName.baseName.text)
		}
		return .visitChildren
	}

	// 현재 scope에 지역 binding 추가
	private func insert(_ name: String) {
		guard var scope = scopes.popLast() else {
			return
		}
		scope.insert(name)
		scopes.append(scope)
	}

	// 가장 안쪽 scope부터 bare name 가림 확인
	private func isShadowed(_ name: String) -> Bool {
		scopes.reversed().contains { $0.contains(name) }
	}

	// 선언된 input 멤버만 기록
	private func record(_ name: String) {
		guard memberNames.contains(name) else {
			return
		}
		members.insert(name)
	}

	// 지원하지 않는 구문 안에 실제 graph input 사용이 있을 때만 경고 추가
	private func recordUnsupportedInputUse(in node: some SyntaxProtocol, code: WorkspaceDiagnosticCode) {
		let source = node.trimmedDescription
		guard source.contains("self.input") || (!isShadowed("input") && source.contains("input")) else {
			return
		}
		unsupported.append(WorkspaceUnsupportedInputReference(
			code: code,
			utf8Offset: node.positionAfterSkippingLeadingTrivia.utf8Offset
		))
	}
}

// initializer parameter의 내부 이름 반환
func workspaceParameterName(_ parameter: FunctionParameterSyntax) -> String {
	(parameter.secondName ?? parameter.firstName).text
}

// argument label 집합에 정확히 맞는 initializer 반환
func workspaceInitializer(
	in memberBlock: MemberBlockSyntax,
	labels: Set<String>
) -> InitializerDeclSyntax? {
	let candidates = memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
		.filter { initializer in
			Set(initializer.signature.parameterClause.parameters.map { $0.firstName.text }) == labels
		}
	return candidates.count == 1 ? candidates.first : nil
}
