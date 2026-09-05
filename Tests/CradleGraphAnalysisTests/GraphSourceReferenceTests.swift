//
//  GraphSourceReferenceTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxBuilder
import SwiftSyntax
import Testing
@testable import CradleGraphAnalysis

// 명시적 self와 closure capture의 source 참조를 함께 수집하는지 확인
@Test
func graphSourceReferencesCollectsDirectReferences() throws {
	let factory = try FunctionDeclSyntax(
		"""
		private func makeFeature() -> Feature {
			let transform = { [appGraph] in appGraph.feature }
			return Feature(value: self.sessionGraph.feature)
		}
		"""
	)

	let references = graphSourceReferences(
		in: factory,
		sourceNames: ["appGraph", "sessionGraph"]
	)

	#expect(references.sourceNames == ["appGraph", "sessionGraph"])
}

// 지역 binding이 가린 source 이름을 수집하지 않는지 확인
@Test
func graphSourceReferencesIgnoresLocalShadowing() throws {
	let factory = try FunctionDeclSyntax(
		"private func makeFeature() -> Feature { let appGraph = LocalGraph(); return appGraph.feature }"
	)

	#expect(graphSourceReferences(in: factory, sourceNames: ["appGraph"]).sourceNames.isEmpty)
}
