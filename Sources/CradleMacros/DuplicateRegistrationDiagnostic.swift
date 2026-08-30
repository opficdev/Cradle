//
//  DuplicateRegistrationDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 8/30/26.
//

import SwiftDiagnostics

// 같은 생성 접근자를 만드는 Factory 등록 그룹의 오류
struct DuplicateRegistrationDiagnostic: DiagnosticMessage {
	// 백틱 표기를 제외한 충돌 접근자 식별자
	let accessorIdentifier: String

	// 기존 중복 진단과 동일한 고정 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "duplicateAccessor")
	}

	// 충돌 그룹이 공유하는 생성 접근자 안내
	var message: String {
		"`\(accessorIdentifier)` 생성 접근자를 만드는 등록이 중복됩니다."
	}

	// 중복 등록이 있는 그래프의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 중복 그룹에 속한 Factory의 등록 위치와 반환 타입 안내
struct DuplicateRegistrationProviderNote: NoteMessage {
	// 해당 등록을 선언한 Factory 이름
	let factoryName: String
	// 원문 표기를 보존한 Factory 반환 타입
	let returnType: String

	// Factory와 반환 타입에 영향을 받지 않는 등록 위치 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "duplicateAccessorProvider")
	}

	// 등록 위치에 대응하는 Factory와 선언된 반환 타입 설명
	var message: String {
		// 백틱 이름을 중복 인용하지 않는 표시용 Factory 이름
		let name = if factoryName.hasPrefix("`"), factoryName.hasSuffix("`") {
			factoryName
		} else {
			"`\(factoryName)`"
		}
		return "\(name) Factory의 등록입니다. 반환 타입은 `\(returnType)`입니다."
	}
}
