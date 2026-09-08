//
//  WorkspaceCompositionEvaluator.swift
//  CradleGraphAnalysis
//
//  Created by opfic on 9/8/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// swiftlint:disable file_length
// 조립 객체와 graph 멤버 접근을 평가하는 분석기 확장
extension WorkspaceCompositionAnalyzer {
	// graph Factory가 직접 읽는 선언된 input 저장 멤버 수집
	func inputMembersRead(
		by factoryName: String,
		in graph: WorkspaceGraphDescriptor
	) -> WorkspaceInputReferenceCollection {
		guard let declaration = index.typeDeclaration(for: graph.id),
			let inputTypeName = declaration.graphInputTypeName,
			let inputType = resolveType(inputTypeName, in: WorkspaceCompositionEvaluationContext(
				source: graph.context,
				lexicalPath: Array(graph.id.lexicalPath.dropLast())
			)),
			inputType.kind == .struct,
			let function = workspaceProviderFunction(
				named: factoryName,
				in: declaration.memberBlock
			) else {
			return WorkspaceInputReferenceCollection(members: [], unsupported: [])
		}
		let members = Set(workspaceDirectStoredLetMemberNames(in: inputType.memberBlock))
		guard !members.isEmpty, let body = function.body else {
			return WorkspaceInputReferenceCollection(members: [], unsupported: [])
		}
		let parameters = Set(function.signature.parameterClause.parameters.map {
			workspaceParameterName($0)
		})
		let collector = WorkspaceInputMemberReferenceCollector(
			memberNames: members,
			parameterNames: parameters
		)
		collector.walk(body)
		return WorkspaceInputReferenceCollection(
			members: collector.members,
			unsupported: collector.unsupported
		)
	}

	// graph input struct의 실제 initializer 대입을 member 값으로 변환
	// swiftlint:disable:next cyclomatic_complexity function_body_length
	func workspaceInputArguments(
		_ expression: ExprSyntax?,
		environment: [String: WorkspaceCompositionValue],
		graph: WorkspaceCompositionGraph,
		contextKey: String,
		inputGraph: WorkspaceGraphDescriptor
	) -> [String: WorkspaceCompositionValue] {
		guard let call = expression?.as(FunctionCallExprSyntax.self),
			let inputTypeName = index.typeDeclaration(for: inputGraph.id)?.graphInputTypeName,
			let inputType = resolveType(inputTypeName, in: WorkspaceCompositionEvaluationContext(
				source: inputGraph.context,
				lexicalPath: Array(inputGraph.id.lexicalPath.dropLast())
			)),
			inputType.kind == .struct else {
			return unknownInputMembers(
				for: inputGraph,
				message: "graph input initializer를 해석할 수 없습니다"
			)
		}
		let callerContext = evaluationContexts.last ?? WorkspaceCompositionEvaluationContext(
			source: graph.descriptor.context,
			lexicalPath: graph.descriptor.id.lexicalPath
		)
		guard resolveType(call.calledExpression.trimmedDescription, in: callerContext)?.id == inputType.id else {
			return unknownInputMembers(
				for: inputGraph,
				message: "graph input에 지정한 생성자를 확인할 수 없습니다"
			)
		}
		let members = workspaceDirectStoredLetMemberNames(in: inputType.memberBlock)
		guard !members.isEmpty else {
			return unknownInputMembers(
				for: inputGraph,
				message: "graph input의 직접 let 저장 멤버가 없습니다"
			)
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
		let labels = arguments.map(\.label)
		let initializers = workspaceInitializers(
			in: inputType.memberBlock,
			labels: labels
		)
		if workspaceCanSynthesizeMemberwiseInitializer(in: inputType.memberBlock),
			labels == members.map(Optional.some) {
			return Dictionary(uniqueKeysWithValues: zip(members, arguments.map(\.value)))
		}
		guard initializers.count == 1, let initializer = initializers.first else {
			return unknownInputMembers(
				for: inputGraph,
				message: "graph input initializer 후보를 하나로 정할 수 없습니다"
			)
		}
		var parameters = [String: WorkspaceCompositionValue]()
		for (parameter, argument) in zip(initializer.signature.parameterClause.parameters, arguments) {
			let name = workspaceParameterName(parameter)
			guard parameters[name] == nil else {
				return unknownInputMembers(
					for: inputGraph,
					message: "graph input initializer의 매개변수 이름이 겹칩니다"
				)
			}
			parameters[name] = argument.value
		}
		guard let body = initializer.body else {
			return unknownInputMembers(
				for: inputGraph,
				message: "graph input initializer 본문이 없습니다"
			)
		}
		var values = [String: WorkspaceCompositionValue]()
		for statement in body.statements {
			guard case let .expr(expression) = statement.item else {
				return unknownInputMembers(
					for: inputGraph,
					message: "graph input initializer에 지원하지 않는 구문이 있습니다"
				)
			}
			guard let assignment = workspaceStoredLetAssignment(
				from: expression,
				memberNames: Set(members)
			) else {
				return unknownInputMembers(
					for: inputGraph,
					message: "graph input initializer에 지원하지 않는 구문이 있습니다"
				)
			}
			guard values[assignment.member] == nil else {
				return unknownInputMembers(
					for: inputGraph,
					message: "graph input 저장 멤버에 여러 번 대입했습니다"
				)
			}
			values[assignment.member] = evaluate(
				assignment.expression,
				environment: parameters,
				graph: graph,
				contextKey: contextKey
			)
		}
		guard Set(values.keys) == Set(members) else {
			return unknownInputMembers(
				for: inputGraph,
				message: "graph input 저장 멤버 대입이 완전하지 않습니다"
			)
		}
		return values
	}

	// graph input 해석 실패 시 알려진 멤버마다 unknown 값을 보존
	func unknownInputMembers(
		for graph: WorkspaceGraphDescriptor,
		message: String
	) -> [String: WorkspaceCompositionValue] {
		guard let inputTypeName = index.typeDeclaration(for: graph.id)?.graphInputTypeName,
			let inputType = resolveType(inputTypeName, in: WorkspaceCompositionEvaluationContext(
				source: graph.context,
				lexicalPath: Array(graph.id.lexicalPath.dropLast())
			)) else {
			return [:]
		}
		return Dictionary(uniqueKeysWithValues: workspaceDirectStoredLetMemberNames(
			in: inputType.memberBlock
		).map { member in
			(member, unknown(message, location: graph.location, context: graph))
		})
	}

	// 일반 조립 객체의 stored let 초기화식과 initializer assignment 평가
	// swiftlint:disable:next cyclomatic_complexity function_body_length
	func constructObject(
		_ type: WorkspaceTypeDeclaration,
		arguments: [WorkspaceCompositionCallArgument],
		identity: String,
		graph: WorkspaceCompositionGraph,
		contextKey: String
	) -> WorkspaceCompositionObject {
		evaluationContexts.append(WorkspaceCompositionEvaluationContext(
			source: type.context,
			lexicalPath: type.id.lexicalPath
		))
		defer { evaluationContexts.removeLast() }
		let object = WorkspaceCompositionObject(
			key: "composition/object/\(identity)",
			declaration: type
		)
		recordCompositionObject(object)
		var environment = [String: WorkspaceCompositionValue]()
		let storedMemberNames = Set(workspaceDirectStoredLetMemberNames(in: type.memberBlock))
		for member in type.memberBlock.members {
			guard let variable = member.decl.as(VariableDeclSyntax.self) else {
				continue
			}
			for binding in variable.bindings {
				guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
					storedMemberNames.contains(identifier.identifier.text),
					let initializer = binding.initializer else {
					continue
				}
				let value = evaluate(
					initializer.value,
					environment: [:],
					graph: graph,
					contextKey: contextKey
				)
				object.members[identifier.identifier.text] = value
				recordCompositionStorage(value, in: object, expression: initializer.value, boundNames: [])
			}
		}
		let initializers = workspaceInitializers(
			in: type.memberBlock,
			labels: arguments.map(\.label)
		)
		if initializers.isEmpty, arguments.isEmpty {
			return object
		}
		guard initializers.count == 1, let initializer = initializers.first else {
			_ = unknown(
				"조립 객체 initializer 후보를 하나로 정할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor,
				code: .ambiguousInitializer
			)
			return object
		}
		for (parameter, argument) in zip(initializer.signature.parameterClause.parameters, arguments) {
			let internalName = workspaceParameterName(parameter)
			guard environment[internalName] == nil else {
				_ = unknown(
					"조립 객체 initializer의 매개변수 이름이 겹칩니다",
					location: graph.descriptor.location,
					context: graph.descriptor,
					code: .ambiguousInitializer
				)
				return object
			}
			environment[internalName] = argument.value
		}
		for (member, value) in object.members where environment[member] == nil {
			environment[member] = value
		}
		if let body = initializer.body {
			for statement in body.statements {
				guard case let .expr(expression) = statement.item,
					let assignment = workspaceStoredLetAssignment(
						from: expression,
						memberNames: storedMemberNames
					) else {
					_ = unknown(
						"조립 객체 initializer에 지원하지 않는 구문이 있습니다",
						location: graph.descriptor.location,
						context: graph.descriptor,
						code: .unsupportedControlFlow
					)
					return object
				}
				guard object.members[assignment.member] == nil else {
					_ = unknown(
						"조립 객체 저장 멤버에 여러 번 대입했습니다",
						location: graph.descriptor.location,
						context: graph.descriptor,
						code: .unsupportedMember
					)
					return object
				}
				let value = evaluate(
					assignment.expression,
					environment: environment,
					graph: graph,
					contextKey: contextKey
				)
				object.members[assignment.member] = value
				recordCompositionStorage(
					value, in: object, expression: assignment.expression, boundNames: Set(environment.keys)
				)
				if environment[assignment.member] == nil {
					environment[assignment.member] = value
				}
			}
		}
		return object
	}

	// graph·object·provider value의 멤버 접근 평가
	func evaluateMember(
		base: WorkspaceCompositionValue,
		name: String,
		graph: WorkspaceCompositionGraph,
		contextKey: String
	) -> WorkspaceCompositionValue {
		switch base {
		case let .graph(instance):
			let matches = instance.providers.filter { provider in
				graphAccessorName(for: TypeSyntax(stringLiteral: provider.descriptor.typeName)) == name
			}
			if matches.count == 1, let provider = matches.first {
				return .provider(provider, accessKey: contextKey)
			}
			return unknown(
				"`\(name)` graph accessor를 해석할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		case let .object(object):
			return object.members[name] ?? unknown(
				"`\(name)` 저장 멤버를 해석할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		case let .provider(provider, accessKey):
			let value = materialize(provider, contextKey: accessKey ?? contextKey)
			guard case .provider = value else {
				return evaluateMember(base: value, name: name, graph: graph, contextKey: contextKey)
			}
			return unknown(
				"`\(name)`은 일반 provider 결과의 멤버여서 해석할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		case .input, .unknown:
			return unknown(
				"`\(name)` 멤버의 출처를 해석할 수 없습니다",
				location: graph.descriptor.location,
				context: graph.descriptor
			)
		}
	}

	// 명목 생성자 이름을 현재 module 또는 직접 import module 선언으로 해석
	func resolveType(
		_ name: String,
		in context: WorkspaceCompositionEvaluationContext
	) -> WorkspaceTypeDeclaration? {
		let components = name.split(separator: ".").map(String.init)
		guard !components.isEmpty else {
			return nil
		}
		var scope = context.lexicalPath
		while true {
			let prefix = WorkspaceDeclarationID(targetID: context.source.targetID, lexicalPath: scope + [components[0]])
			if index.nominalTypes.contains(where: { $0.id == prefix }) {
				let identifier = WorkspaceDeclarationID(targetID: context.source.targetID, lexicalPath: scope + components)
				return index.typeDeclaration(for: identifier)
			}
			guard !scope.isEmpty else { break }
			scope.removeLast()
		}
		var candidates = [WorkspaceDeclarationID]()
		if 1 < components.count,
			let module = index.targets.first(where: { $0.moduleName == components[0] }),
			context.source.moduleName == module.moduleName
				|| (context.source.importedModules.contains(module.moduleName)
					&& context.source.dependencyIDs.contains(module.id)) {
			candidates.append(WorkspaceDeclarationID(
				targetID: module.id,
				lexicalPath: Array(components.dropFirst())
			))
		}
		for target in index.targets where context.source.importedModules.contains(target.moduleName)
			&& context.source.dependencyIDs.contains(target.id) {
			candidates.append(WorkspaceDeclarationID(targetID: target.id, lexicalPath: components))
		}
		let resolved = Array(Set(candidates)).filter { candidate in
			index.nominalTypes.contains { $0.id == candidate }
		}.sorted()
		guard resolved.count == 1, let identifier = resolved.first else {
			return nil
		}
		return index.typeDeclaration(for: identifier)
	}

	// input node가 실제 provider 또는 graph에 연결될 때 node key 반환
	func nodeKey(
		for value: WorkspaceCompositionValue,
		graph: WorkspaceCompositionGraph
	) -> String? {
		switch value {
		case let .provider(provider, _):
			return provider.key
		case let .graph(instance):
			return instance.key
		case .object, .input:
			return nil
		case .unknown:
			unknownNodeCount += 1
			let key = "composition/unknown/\(graph.key)/\(unknownNodeCount)"
			nodes[key] = WorkspaceDiagramNode(
				key: key,
				kind: .unknown,
				targetID: graph.descriptor.id.targetID,
				label: "미해석",
				location: graph.descriptor.location,
				graphKey: graph.key
			)
			return key
		}
	}

	// 미해석 값을 진단과 함께 생성
	func unknown(
		_ message: String,
		location: WorkspaceSourceLocation,
		context: WorkspaceGraphDescriptor,
		code: WorkspaceDiagnosticCode = .unresolvedType
	) -> WorkspaceCompositionValue {
		diagnostics.insert(WorkspaceDiagramDiagnostic(
			code: code,
			message: message,
			location: location,
			context: WorkspaceDiagnosticContext(
				targetID: context.id.targetID,
				declarationID: context.id
			)
		))
		return .unknown(message)
	}

	// edge와 근거 위치 병합
	func insertEdge(
		from: String,
		to destination: String,
		kind: WorkspaceDiagramEdgeKind,
		location: WorkspaceSourceLocation
	) {
		let key = WorkspaceCompositionEdgeKey(
			from: from,
			destination: destination,
			kind: kind
		)
		edges[key, default: []].insert(location)
	}
}
// swiftlint:enable file_length
