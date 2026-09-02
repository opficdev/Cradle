//
//  InvalidProviderLifetimeDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics

// 직접 작성한 shared case 이외의 수명 인자 오류
struct InvalidProviderLifetimeDiagnostic: DiagnosticMessage {
	// 입력 표현식에 영향을 받지 않는 진단 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "invalidProviderLifetime")
	}

	// 지원하는 인자 생략과 직접 case 표기 안내
	var message: String {
		"`@Provide` 인자는 생략하거나 `.shared`로 직접 지정해야 합니다."
	}

	// 잘못된 수명 인자를 포함한 graph의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}
