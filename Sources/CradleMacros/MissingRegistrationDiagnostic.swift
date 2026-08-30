//
//  MissingRegistrationDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 8/30/26.
//

import SwiftDiagnostics

// 등록되지 않은 지역 이름을 요구하는 Factory 매개변수 오류
struct MissingRegistrationDiagnostic: DiagnosticMessage {
	// 누락된 의존성을 요구한 Factory 이름
	let factoryName: String
	// 등록 생성 접근자와 일치하지 않는 지역 이름
	let localName: String

	// Factory와 매개변수 이름에 영향을 받지 않는 누락 진단 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "missingRegistration")
	}

	// 누락된 등록과 이를 요구한 Factory를 함께 표시하는 오류 문구
	var message: String {
		"\(quotedFactoryName(factoryName))의 매개변수 `\(localName)`에 대응하는 등록이 없습니다."
	}

	// 누락된 등록이 있는 그래프의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}

// 누락된 의존성을 요구한 Factory의 등록 위치 안내
struct MissingRegistrationProviderNote: NoteMessage {
	// 관련 등록 위치에 선언된 Factory 이름
	let factoryName: String

	// Factory 이름에 영향을 받지 않는 등록 위치 설명 식별자
	var noteID: MessageID {
		MessageID(domain: "Cradle", id: "missingRegistrationProvider")
	}

	// 보조 설명이 가리키는 Factory의 의존성 요구 안내
	var message: String {
		"\(quotedFactoryName(factoryName)) Factory가 이 의존성을 요구합니다."
	}
}

// 생성 호출용 이름을 바꾸지 않고 진단 문구에서 Factory 이름을 한 번만 인용
private func quotedFactoryName(_ name: String) -> String {
	if name.hasPrefix("`"), name.hasSuffix("`") {
		return name
	}
	return "`\(name)`"
}
