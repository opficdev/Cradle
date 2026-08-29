//
//  CradleMacroTestSupport.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import SwiftSyntaxMacros
@testable import CradleMacros

// Macro expansion test용 Cradle Macro 이름표
let testMacros: [String: Macro.Type] = [
	"DependencyGraph": DependencyGraphMacro.self,
	"Provide": ProvideMacro.self
]
