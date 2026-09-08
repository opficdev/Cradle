//
//  WorkspaceCompositionAnalyzer.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// swiftlint:disable file_length
// 제한된 생성자·저장 멤버 구문으로 graph input 출처를 추적하는 분석기
// swiftlint:disable:next type_body_length
package final class WorkspaceCompositionAnalyzer {
	// workspace 선언 index
	let index: WorkspaceDeclarationIndex
	// root graph 선언
	let roots: [WorkspaceDeclarationID]
	// 일반 조립 객체로 확장할 type 선언
	let compositionTypes: Set<WorkspaceDeclarationID>
	// 생성된 Mermaid node
	var nodes = [String: WorkspaceDiagramNode]()
	// 중복을 병합할 Mermaid edge
	var edges = [WorkspaceCompositionEdgeKey: Set<WorkspaceSourceLocation>]()
	// 부분 분석 진단
	var diagnostics = Set<WorkspaceDiagramDiagnostic>()
	// provider 조립 결과 cache
	var materializedProviders = [String: WorkspaceCompositionValue]()
	// 순환 provider 평가 방지
	var evaluatingProviders = Set<String>()
	// 생성 문맥별 provider 순환 평가 방지
	var evaluatingProviderDeclarations = Set<String>()
	// 미해석 node의 결정적 생성 순서
	var unknownNodeCount = 0
	// 생성한 일반 조립 객체 수
	var constructedObjectCount = 0
	// 현재 평가하는 Factory 또는 조립 type의 source 문맥
	var evaluationContexts = [WorkspaceCompositionEvaluationContext]()

	package init(
		index: WorkspaceDeclarationIndex,
		roots: [WorkspaceDeclarationID],
		compositionTypes: Set<WorkspaceDeclarationID>
	) {
		self.index = index
		self.roots = roots.sorted()
		self.compositionTypes = compositionTypes
	}

	// root graph부터 도달 가능한 조립 관계 분석
	package func analyze() -> WorkspaceDiagramModel {
		for root in roots {
			guard let graph = index.graphs.first(where: { $0.id == root }) else {
				continue
			}
			let instance = constructGraph(
				graph,
				inputs: [:],
				sources: [:],
				identity: "root/\(root.targetID.rawValue)/\(root.lexicalName)"
			)
			for provider in instance.providers {
				_ = materialize(provider, contextKey: provider.key)
			}
		}
		return WorkspaceDiagramModel(
			targets: index.targets,
			nodes: Array(nodes.values),
			edges: edges.map { key, evidence in
				WorkspaceDiagramEdge(from: key.from, to: key.destination, kind: key.kind, evidence: Array(evidence))
			},
			diagnostics: Array(diagnostics)
		)
	}

	// graph instance와 provider node·input node를 생성
	// swiftlint:disable:next function_body_length
	private func constructGraph(
		_ descriptor: WorkspaceGraphDescriptor,
		inputs: [String: WorkspaceCompositionValue],
		sources: [String: WorkspaceCompositionValue],
		identity: String
	) -> WorkspaceCompositionGraph {
		let graph = WorkspaceCompositionGraph(key: "composition/graph/\(identity)", descriptor: descriptor, inputs: inputs, sources: sources)
		nodes[graph.key] = WorkspaceDiagramNode(
			key: graph.key,
			kind: .graph,
			targetID: descriptor.id.targetID,
			label: "\(descriptor.context.moduleName).\(descriptor.id.lexicalName)",
			location: descriptor.location,
			graphKey: graph.key
		)
		for provider in graph.providers {
			nodes[provider.key] = WorkspaceDiagramNode(
				key: provider.key,
				kind: .provider,
				targetID: descriptor.id.targetID,
				label: "\(provider.descriptor.typeName)<br/>\(provider.descriptor.factoryName)<br/>.\(provider.descriptor.lifetime.rawValue)",
				lifetime: provider.descriptor.lifetime.rawValue,
				location: descriptor.location,
				graphKey: graph.key
			)
			for dependency in provider.descriptor.dependencyIdentities {
				let candidates = graph.providers.filter { $0.descriptor.identity == dependency }
				guard candidates.count == 1, let candidate = candidates.first else {
					continue
				}
				insertEdge(
					from: provider.key,
					to: candidate.key,
					kind: .providerParameter,
					location: descriptor.location
				)
			}
			let references = inputMembersRead(by: provider.descriptor.factoryName, in: descriptor)
			for unsupported in references.unsupported {
				diagnostics.insert(WorkspaceDiagramDiagnostic(
					code: unsupported.code,
					message: "지원하지 않는 graph input 사용",
					location: WorkspaceSourceLocation(
						targetID: descriptor.id.targetID,
						path: descriptor.context.path,
						utf8Offset: unsupported.utf8Offset
					),
					context: WorkspaceDiagnosticContext(
						targetID: descriptor.id.targetID,
						declarationID: descriptor.id,
						memberName: provider.descriptor.factoryName
					)
				))
			}
			for member in references.members.sorted() {
				let inputKey = "composition/input/\(identity)/\(member)"
				nodes[inputKey] = WorkspaceDiagramNode(
					key: inputKey,
					kind: .input,
					targetID: descriptor.id.targetID,
					label: "input.\(member)",
					location: descriptor.location,
					graphKey: graph.key
				)
				insertEdge(from: provider.key, to: inputKey, kind: .inputRead, location: descriptor.location)
				if let value = inputs[member], let sourceKey = nodeKey(for: value, graph: graph) {
					insertEdge(from: inputKey, to: sourceKey, kind: .inputBinding, location: descriptor.location)
				}
			}
			for sourceName in provider.descriptor.sourceNames {
				guard let value = sources[sourceName], let sourceKey = nodeKey(for: value, graph: graph) else {
					continue
				}
				insertEdge(from: provider.key, to: sourceKey, kind: .sourceRead, location: descriptor.location)
			}
		}
		for source in descriptor.diagram.sources {
			guard let value = sources[source.name], let sourceKey = nodeKey(for: value, graph: graph) else {
				continue
			}
			insertEdge(from: graph.key, to: sourceKey, kind: .sourceDeclaration, location: descriptor.location)
		}
		return graph
	}

	// provider가 일반 조립 객체를 반환할 때만 본문을 제한적으로 확장
	// swiftlint:disable:next function_body_length
	func materialize(
		_ provider: WorkspaceCompositionProvider,
		contextKey: String
	) -> WorkspaceCompositionValue {
		guard contextKey.split(separator: "/").count <= 128,
			materializedProviders.count < 10_000 else {
			return unknown(
				"조립 분석 한도를 넘었습니다",
				location: provider.graph.descriptor.location,
				context: provider.graph.descriptor,
				code: .analysisLimit
			)
		}
		let cacheKey = provider.descriptor.lifetime == .transient
			? "\(provider.key)/\(contextKey)"
			: provider.key
		if let cached = materializedProviders[cacheKey] {
			return cached
		}
		guard evaluatingProviders.insert(cacheKey).inserted,
			evaluatingProviderDeclarations.insert(provider.key).inserted else {
			return unknown(
				"provider 순환: \(provider.descriptor.factoryName)",
				location: provider.graph.descriptor.location,
				context: provider.graph.descriptor,
				code: .cyclicEvaluation
			)
		}
		defer {
			evaluatingProviders.remove(cacheKey)
			evaluatingProviderDeclarations.remove(provider.key)
		}
		evaluationContexts.append(WorkspaceCompositionEvaluationContext(
			source: provider.graph.descriptor.context,
			lexicalPath: provider.graph.descriptor.id.lexicalPath
		))
		defer { evaluationContexts.removeLast() }
		let type = resolveType(provider.descriptor.identity.canonicalText, in: evaluationContexts.last!)
		let function = index.typeDeclaration(for: provider.graph.descriptor.id).flatMap {
			workspaceProviderFunction(named: provider.descriptor.factoryName, in: $0.memberBlock)
		}
		guard let type, compositionTypes.contains(type.id), let function else {
			let value = WorkspaceCompositionValue.provider(provider, accessKey: contextKey)
			materializedProviders[cacheKey] = value
			return value
		}
		var environment = [String: WorkspaceCompositionValue]()
		for parameter in function.signature.parameterClause.parameters {
			let name = workspaceParameterName(parameter)
			let identity = graphTypeIdentity(for: parameter.type)
			let candidates = provider.graph.providers.filter { $0.descriptor.identity == identity }
			if candidates.count == 1, let candidate = candidates.first {
				environment[name] = .provider(candidate, accessKey: "\(contextKey)/\(name)")
				insertEdge(
					from: provider.key,
					to: candidate.key,
					kind: .providerParameter,
					location: provider.graph.descriptor.location
				)
			} else {
				environment[name] = unknown(
					"`\(name)` provider 후보를 하나로 정할 수 없습니다",
					location: provider.graph.descriptor.location,
					context: provider.graph.descriptor
				)
			}
		}
		guard function.body != nil else {
			let value = WorkspaceCompositionValue.provider(provider, accessKey: contextKey)
			materializedProviders[cacheKey] = value
			return value
		}
		let value = evaluateFactoryBody(
			function,
			environment: &environment,
			graph: provider.graph,
			contextKey: cacheKey
		)
		materializedProviders[cacheKey] = value
		return value
	}

	// Factory 본문의 직접 let과 마지막 반환식 평가
	private func evaluateFactoryBody(
		_ function: FunctionDeclSyntax,
		environment: inout [String: WorkspaceCompositionValue],
		graph: WorkspaceCompositionGraph,
		contextKey: String
	) -> WorkspaceCompositionValue {
		guard let body = function.body else { return .unknown("본문 없음") }
		for statement in body.statements {
			if let variable = statement.item.as(VariableDeclSyntax.self) {
				for binding in variable.bindings {
					guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
						let initializer = binding.initializer else {
						continue
					}
					environment[pattern.identifier.text] = evaluate(
						initializer.value,
						environment: environment,
						graph: graph,
						contextKey: contextKey
					)
				}
				continue
			}
			if let returnStatement = statement.item.as(ReturnStmtSyntax.self), let expression = returnStatement.expression {
				return evaluate(expression, environment: environment, graph: graph, contextKey: contextKey)
			}
			if let expression = statement.item.as(ExprSyntax.self) {
				return evaluate(expression, environment: environment, graph: graph, contextKey: contextKey)
			}
		}
		return unknown(
			"`\(function.name.text)` Factory의 반환식을 해석할 수 없습니다",
			location: graph.descriptor.location,
			context: graph.descriptor
		)
	}

	// 직접 생성·참조·멤버 접근만 제한적으로 평가
	func evaluate(
		_ expression: ExprSyntax,
		environment: [String: WorkspaceCompositionValue],
		graph: WorkspaceCompositionGraph,
		contextKey: String
	) -> WorkspaceCompositionValue {
		if let reference = expression.as(DeclReferenceExprSyntax.self) {
			return environment[reference.baseName.text] ?? unknown(
				"`\(reference.baseName.text)` 값의 출처를 해석할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		}
		if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
			return evaluateMember(
				base: evaluate(base, environment: environment, graph: graph, contextKey: contextKey),
				name: member.declName.baseName.text,
				graph: graph,
				contextKey: "\(contextKey)/\(member.positionAfterSkippingLeadingTrivia.utf8Offset)"
			)
		}
		if let call = expression.as(FunctionCallExprSyntax.self) {
			return evaluateCall(call, environment: environment, graph: graph, contextKey: contextKey)
		}
		if let parentheses = expression.as(TupleExprSyntax.self), parentheses.elements.count == 1,
			let element = parentheses.elements.first {
			return evaluate(element.expression, environment: environment, graph: graph, contextKey: contextKey)
		}
		return unknown(
			"지원하지 않는 조립 expression: \(expression.trimmedDescription)",
			location: graph.descriptor.location,
			context: graph.descriptor,
			code: .unsupportedExpression
		)
	}

	// 생성자 호출을 graph instance 또는 허용한 일반 조립 객체로 변환
	// swiftlint:disable:next function_body_length
	private func evaluateCall(
		_ call: FunctionCallExprSyntax,
		environment: [String: WorkspaceCompositionValue],
		graph: WorkspaceCompositionGraph,
		contextKey: String
	) -> WorkspaceCompositionValue {
		let name = call.calledExpression.trimmedDescription
		let context = evaluationContexts.last ?? WorkspaceCompositionEvaluationContext(
			source: graph.descriptor.context,
			lexicalPath: graph.descriptor.id.lexicalPath
		)
		guard let type = resolveType(name, in: context) else {
			return unknown(
				"`\(name)` 생성자 선언을 해석할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		}
		let identity = "\(contextKey)/\(context.source.path)/\(call.positionAfterSkippingLeadingTrivia.utf8Offset)/\(type.id.lexicalName)"
		if let graphDescriptor = index.graphs.first(where: { $0.id == type.id }) {
			let inputExpression = call.arguments.first(where: { $0.label?.text == "input" })?.expression
			let inputs = workspaceInputArguments(
				inputExpression,
				environment: environment,
				graph: graph,
				contextKey: contextKey,
				inputGraph: graphDescriptor
			)
			let sourceNames = Set(graphDescriptor.diagram.sources.map(\.name))
			let sources: [String: WorkspaceCompositionValue] = Dictionary(
				uniqueKeysWithValues: call.arguments.compactMap { argument in
				guard let label = argument.label?.text, sourceNames.contains(label) else { return nil }
				return (label, evaluate(argument.expression, environment: environment, graph: graph, contextKey: contextKey))
				}
			)
			let instance = constructGraph(graphDescriptor, inputs: inputs, sources: sources, identity: identity)
			instance.providers.forEach { provider in
				_ = materialize(provider, contextKey: "\(identity)/\(provider.descriptor.factoryName)")
			}
			return .graph(instance)
		}
		let arguments = call.arguments.map { argument in
			WorkspaceCompositionCallArgument(
				label: argument.label?.text,
				value: evaluate(
					argument.expression,
					environment: environment,
					graph: graph,
					contextKey: contextKey
				)
			)
		}
		guard compositionTypes.contains(type.id) else {
			return unknown(
				"`\(name)`은 compositionTypes에 포함되지 않았습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		}
		guard contextKey.split(separator: "/").count <= 128,
			constructedObjectCount < 10_000 else {
			return unknown(
				"조립 객체 분석 한도를 넘었습니다",
				location: graph.descriptor.location,
				context: graph.descriptor,
				code: .analysisLimit
			)
		}
		constructedObjectCount += 1
		return .object(constructObject(
			type,
			arguments: arguments,
			identity: identity,
			graph: graph,
			contextKey: identity
		))
	}

}
// swiftlint:enable file_length
