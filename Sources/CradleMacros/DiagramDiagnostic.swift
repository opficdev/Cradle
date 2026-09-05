//
//  DiagramDiagnostic.swift
//  CradleMacros
//
//  Created by opfic on 9/4/26.
//

import SwiftDiagnostics

// Mermaid 산출물 제외 표식의 구문 진단
enum DiagramDiagnostic: DiagnosticMessage {
	// `diagram` 인자의 정적 Bool literal 제약
	case invalidConfiguration

	// 경우별 고정 진단 식별자
	var diagnosticID: MessageID {
		switch self {
		case .invalidConfiguration:
			MessageID(domain: "Cradle", id: "invalidDiagramConfiguration")
		}
	}

	// 경우별 사용자 오류 설명
	var message: String {
		switch self {
		case .invalidConfiguration:
			"`diagram`은 직접 작성한 `true` 또는 `false`여야 합니다."
		}
	}

	// 지원하지 않는 표식은 graph 생성 중단
	var severity: DiagnosticSeverity { .error }
}
