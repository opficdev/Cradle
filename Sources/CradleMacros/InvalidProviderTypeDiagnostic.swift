//
//  InvalidProviderTypeDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics

// provider 등록에 직접 작성한 Optional 타입 오류
struct InvalidProviderTypeDiagnostic: DiagnosticMessage {
	// 입력 타입에 영향을 받지 않는 진단 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "invalidProviderType")
	}

	// Optional을 허용하지 않는 등록 위치 안내
	var message: String {
		"`@Provide`의 반환 타입과 매개변수 타입에는 Optional을 사용할 수 없습니다."
	}

	// 잘못된 등록이 있는 graph의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}
