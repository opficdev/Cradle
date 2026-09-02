//
//  InvalidSharedProviderReferenceDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/2/26.
//

import SwiftDiagnostics

// shared Factory가 transient 등록을 요구할 때의 오류
struct InvalidSharedProviderReferenceDiagnostic: DiagnosticMessage {
	// Factory 이름에 영향을 받지 않는 진단 식별자
	var diagnosticID: MessageID {
		MessageID(domain: "Cradle", id: "invalidSharedProviderReference")
	}

	// graph 초기화 전에 생성할 수 없는 참조 안내
	var message: String {
		"`@Provide(.shared)` Factory는 transient 등록을 매개변수로 받을 수 없습니다."
	}

	// shared 저장소를 만들 수 없는 graph의 컴파일 중단
	var severity: DiagnosticSeverity { .error }
}
