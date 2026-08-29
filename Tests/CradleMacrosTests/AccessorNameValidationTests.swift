//
//  AccessorNameValidationTests.swift
//  CradleMacrosTests
//
//  Created by opfic on 8/29/26.
//

import Testing
@testable import CradleMacros

// Swift 예약어 접근자 이름 거부 확인
@Test(arguments: ["class", "throw", "precedencegroup"])
func rejectsSwiftReservedAccessorNames(name: String) {
	#expect(!isValidAccessorName(name))
}
