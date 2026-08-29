//
//  ProvideMacro.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// 자체 선언을 추가하지 않는 `@Provide` factory 표시
struct ProvideMacro: PeerMacro {
	// `DependencyGraphMacro`가 읽을 marker만 유지
	static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let graph = context.lexicalContext.first?.as(ClassDeclSyntax.self),
			containsAttribute(named: "DependencyGraph", in: graph.attributes) else {
			context.diagnose(Diagnostic(node: node, message: CradleMacroDiagnostic.invalidProvidePlacement))
			return []
		}

		return []
	}
}
