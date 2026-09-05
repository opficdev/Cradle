//
//  GraphTypeIdentityTests.swift
//  CradleGraphAnalysisTests
//
//  Created by opfic on 9/4/26.
//

import SwiftSyntaxBuilder
import SwiftSyntax
import Testing
@testable import CradleGraphAnalysis

// any와 바깥 괄호가 같은 graph 타입 identity를 만드는지 확인
@Test
func graphTypeIdentityNormalizesAnyAndParentheses() {
	let direct = TypeSyntax("Repository")
	let existential = TypeSyntax("(any Repository)")

	#expect(graphTypeIdentity(for: direct) == graphTypeIdentity(for: existential))
}

// provider 수명의 원본 문자열을 보존하는지 확인
@Test(arguments: [GraphProviderLifetime.shared, .transient])
func graphProviderLifetimePreservesRawValue(lifetime: GraphProviderLifetime) {
	#expect(lifetime.rawValue == (lifetime == .shared ? "shared" : "transient"))
}
