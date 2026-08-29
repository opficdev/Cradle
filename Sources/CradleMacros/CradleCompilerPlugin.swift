//
//  CradleCompilerPlugin.swift
//  CradleMacros
//
//  Created by opfic on 8/29/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

// Cradle Macro 구현의 compiler 등록
@main
struct CradleCompilerPlugin: CompilerPlugin {
	// compiler가 찾는 Cradle Macro 목록
	let providingMacros: [Macro.Type] = [
		DependencyGraphMacro.self,
		ProvideMacro.self
	]
}
