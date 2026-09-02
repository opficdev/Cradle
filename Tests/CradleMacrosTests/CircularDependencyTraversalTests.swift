//
//  CircularDependencyTraversalTests.swift
//  CradleTests
//
//  Created by opfic on 8/30/26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import Testing
@testable import CradleMacros

// 깊은 연결의 정상 종료와 중간 등록으로 돌아가는 순환 경로 확인
@Test
func circularDependencyTraversalHandlesLongChains() throws {
	// 재귀 호출 없이 처리할 등록 수
	let count = 2_048
	// 마지막 등록에서 끝나는 긴 의존성 연결
	var connections = (0..<count).map { index in
		index + 1 < count ? [index + 1] : []
	}
	#expect(firstCircularDependency(in: circularDependencyProviders(connections)) == nil)
	connections[count - 1] = [count / 2]
	// 중간 등록으로 돌아가는 첫 순환
	let cycle = try #require(firstCircularDependency(in: circularDependencyProviders(connections)))
	#expect(cycle.providerIndices == Array((count / 2)..<count))
	#expect(cycle.closingParameter.localName == "value1024")
}

// 빈 그래프와 이미 완료된 동일 대상의 중복 참조를 순환으로 오판하지 않는지 확인
@Test
func circularDependencyTraversalReusesCompletedTargets() {
	#expect(firstCircularDependency(in: []) == nil)
	#expect(firstCircularDependency(in: circularDependencyProviders([[1, 1], []])) == nil)
}

// 탐색 함수만 검증하기 위한 원본 매개변수 정보를 가진 등록 구성
private func circularDependencyProviders(_ connections: [[Int]]) -> [ProviderDescriptor] {
	connections.enumerated().compactMap { index, targets in
		let returnType = TypeSyntax(IdentifierTypeSyntax(name: .identifier("Value\(index)")))
		let propertyName = "value\(index)"
		guard let factory = try? FunctionDeclSyntax(
			"private func makeValue\(raw: index)() -> \(raw: returnType.trimmedDescription) {}"
		) else {
			return nil
		}
		return ProviderDescriptor(
			attribute: AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Provide"))),
			factory: factory,
			registeredType: RegisteredType(
				exposedType: returnType,
				identity: registeredTypeIdentity(for: returnType),
				propertyName: propertyName
			),
			parameters: targets.map { target in
				let type = TypeSyntax(IdentifierTypeSyntax(name: .identifier("Value\(target)")))
				let targetName = "value\(target)"
				return ProviderParameterDescriptor(
					externalLabel: targetName,
					localName: targetName,
					localNameToken: .identifier(targetName),
					type: type,
					typeIdentity: registeredTypeIdentity(for: type)
				)
			},
			lifetime: .transient
		)
	}
}
