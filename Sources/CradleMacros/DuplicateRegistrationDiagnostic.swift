//
//  DuplicateRegistrationDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 8/30/26.
//

import SwiftDiagnostics

// 같은 등록 타입 또는 생성 프로퍼티 이름을 공유하는 Factory 오류
struct DuplicateRegistrationDiagnostic: DiagnosticMessage {
	// 중복 등록 타입 또는 충돌 프로퍼티 설명
	private let subject: String
	// 등록 identity 중복 여부
	private let isRegistrationDuplicate: Bool

	// 생성 프로퍼티 이름 충돌 진단 생성
	init(accessorIdentifier: String) {
		subject = accessorIdentifier
		isRegistrationDuplicate = false
	}

	// 동일 등록 타입 중복 진단 생성
	init(registrationType: String) {
		subject = registrationType
		isRegistrationDuplicate = true
	}

	// 기존 중복 진단과 동일한 고정 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "duplicateAccessor")
	}

	// 충돌 그룹의 등록 타입 또는 생성 프로퍼티 안내
	var message: String {
		if isRegistrationDuplicate {
			return "`\(subject)` 등록 타입이 중복됩니다."
		}
		return "`\(subject)` 생성 프로퍼티를 만드는 등록이 중복됩니다."
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

	// 등록 위치에 대응하는 Factory와 등록 타입 설명
	var message: String {
		// 백틱 이름을 중복 인용하지 않는 표시용 Factory 이름
		let name = if factoryName.hasPrefix("`"), factoryName.hasSuffix("`") {
			factoryName
		} else {
			"`\(factoryName)`"
		}
		return "\(name) Factory의 등록입니다. 등록 타입은 `\(returnType)`입니다."
	}
}
